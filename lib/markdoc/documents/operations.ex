defmodule Markdoc.Documents.Operations do
  @moduledoc """
  Operational Transform (OT) implementation for conflict-free collaborative text editing.

  This module provides functions to:
  - Apply text operations (insert, delete, retain)
  - Transform concurrent operations to maintain consistency
  - Compose and invert operations
  - Handle cursor position adjustments
  """

  @type operation :: %{
          type: :insert | :delete | :retain | :replace,
          position: integer(),
          content: binary(),
          length: integer(),
          deleted_length: integer(),
          timestamp: DateTime.t()
        }

  @doc """
  Applies a text operation to content.
  """
  @spec apply_operation(binary(), operation()) :: {:ok, binary()} | {:error, term()}
  def apply_operation(content, %{type: :insert, position: pos, content: text}) do
    if pos >= 0 and pos <= String.length(content) do
      {before, after_text} = split_at_position(content, pos)
      new_content = before <> text <> after_text
      {:ok, new_content}
    else
      {:error, :invalid_position}
    end
  end

  def apply_operation(content, %{type: :delete, position: pos, length: len}) do
    content_length = String.length(content)

    if pos >= 0 and pos < content_length and len > 0 and pos + len <= content_length do
      {before, rest} = split_at_position(content, pos)
      {_deleted, after_text} = split_at_position(rest, len)
      new_content = before <> after_text
      {:ok, new_content}
    else
      {:error, :invalid_position}
    end
  end

  def apply_operation(content, %{
        type: :replace,
        position: pos,
        content: text,
        deleted_length: del_len
      }) do
    content_length = String.length(content)

    if pos >= 0 and pos < content_length and del_len > 0 and pos + del_len <= content_length do
      {before, rest} = split_at_position(content, pos)
      {_deleted, after_text} = split_at_position(rest, del_len)
      new_content = before <> text <> after_text
      {:ok, new_content}
    else
      {:error, :invalid_position}
    end
  end

  def apply_operation(content, %{type: :retain}) do
    # Retain operation doesn't change content
    {:ok, content}
  end

  def apply_operation(_content, _operation) do
    {:error, :invalid_operation}
  end

  @doc """
  Transforms two concurrent operations to maintain consistency.

  This is the core of operational transforms. When two users perform
  operations at the same time, we need to transform them so that
  applying op1 then transform(op2, op1) gives the same result as
  applying op2 then transform(op1, op2).
  """
  @spec transform_operation(operation(), operation()) :: {operation(), operation()}
  def transform_operation(op1, op2) do
    case {op1.type, op2.type} do
      {:insert, :insert} ->
        transform_insert_insert(op1, op2)

      {:insert, :delete} ->
        transform_insert_delete(op1, op2)

      {:delete, :insert} ->
        {op2_transformed, op1_transformed} = transform_insert_delete(op2, op1)
        {op1_transformed, op2_transformed}

      {:delete, :delete} ->
        transform_delete_delete(op1, op2)

      {:replace, :insert} ->
        transform_replace_insert(op1, op2)

      {:insert, :replace} ->
        {op2_transformed, op1_transformed} = transform_replace_insert(op2, op1)
        {op1_transformed, op2_transformed}

      {:replace, :delete} ->
        transform_replace_delete(op1, op2)

      {:delete, :replace} ->
        {op2_transformed, op1_transformed} = transform_replace_delete(op2, op1)
        {op1_transformed, op2_transformed}

      {:replace, :replace} ->
        transform_replace_replace(op1, op2)

      {:retain, _} ->
        {op1, op2}

      {_, :retain} ->
        {op1, op2}
    end
  end

  # Transform two concurrent insert operations
  defp transform_insert_insert(op1, op2) do
    cond do
      op1.position < op2.position ->
        # op1 is before op2, op2 position shifts right
        {op1, %{op2 | position: op2.position + String.length(op1.content)}}

      op1.position > op2.position ->
        # op2 is before op1, op1 position shifts right
        {%{op1 | position: op1.position + String.length(op2.content)}, op2}

      op1.position == op2.position ->
        # Same position - use timestamp to determine order
        if DateTime.compare(op1.timestamp, op2.timestamp) == :lt do
          # op1 comes first
          {op1, %{op2 | position: op2.position + String.length(op1.content)}}
        else
          # op2 comes first
          {%{op1 | position: op1.position + String.length(op2.content)}, op2}
        end
    end
  end

  # Transform insert vs delete operations
  defp transform_insert_delete(insert_op, delete_op) do
    insert_pos = insert_op.position
    delete_start = delete_op.position
    delete_end = delete_op.position + delete_op.length

    cond do
      insert_pos <= delete_start ->
        # Insert is before delete region, delete position shifts right
        {insert_op,
         %{delete_op | position: delete_op.position + String.length(insert_op.content)}}

      insert_pos >= delete_end ->
        # Insert is after delete region, insert position shifts left
        {%{insert_op | position: insert_op.position - delete_op.length}, delete_op}

      insert_pos > delete_start and insert_pos < delete_end ->
        # Insert is within delete region, both operations are affected
        # Delete operation is split, insert position becomes delete start
        new_delete_length = delete_op.length + String.length(insert_op.content)
        {%{insert_op | position: delete_start}, %{delete_op | length: new_delete_length}}
    end
  end

  # Transform two concurrent delete operations
  defp transform_delete_delete(op1, op2) do
    delete1_start = op1.position
    delete1_end = op1.position + op1.length
    delete2_start = op2.position
    delete2_end = op2.position + op2.length

    cond do
      delete1_end <= delete2_start ->
        # delete1 is completely before delete2
        {op1, %{op2 | position: op2.position - op1.length}}

      delete2_end <= delete1_start ->
        # delete2 is completely before delete1
        {%{op1 | position: op1.position - op2.length}, op2}

      true ->
        # Deletes overlap - this is complex, we'll use a simplified approach
        # In practice, you might want more sophisticated handling
        handle_overlapping_deletes(op1, op2)
    end
  end

  defp handle_overlapping_deletes(op1, op2) do
    # Simplified: whoever started first wins the overlapping region
    if op1.position <= op2.position do
      # op1 starts first or at same position
      new_op2_pos = max(op1.position, op2.position + op2.length - op1.length)
      new_op2_length = max(0, op2.position + op2.length - op1.position - op1.length)
      {op1, %{op2 | position: new_op2_pos, length: new_op2_length}}
    else
      # op2 starts first
      new_op1_pos = max(op2.position, op1.position + op1.length - op2.length)
      new_op1_length = max(0, op1.position + op1.length - op2.position - op2.length)
      {%{op1 | position: new_op1_pos, length: new_op1_length}, op2}
    end
  end

  @doc """
  Adjusts cursor position after an operation is applied.
  """
  @spec adjust_cursor_position(integer(), operation()) :: integer()
  def adjust_cursor_position(cursor_pos, %{type: :insert, position: op_pos, content: content}) do
    if cursor_pos > op_pos do
      cursor_pos + String.length(content)
    else
      cursor_pos
    end
  end

  def adjust_cursor_position(cursor_pos, %{type: :delete, position: op_pos, length: length}) do
    cond do
      cursor_pos <= op_pos ->
        cursor_pos

      cursor_pos <= op_pos + length ->
        # Cursor was in deleted region, move to start of deletion
        op_pos

      true ->
        cursor_pos - length
    end
  end

  def adjust_cursor_position(cursor_pos, %{type: :retain}) do
    cursor_pos
  end

  @doc """
  Creates an insert operation.
  """
  @spec insert(integer(), binary()) :: operation()
  def insert(position, content) do
    %{
      type: :insert,
      position: position,
      content: content,
      length: String.length(content),
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Creates a delete operation.
  """
  @spec delete(integer(), integer()) :: operation()
  def delete(position, length) do
    %{
      type: :delete,
      position: position,
      content: "",
      length: length,
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Creates a retain operation (no-op).
  """
  @spec retain() :: operation()
  def retain do
    %{
      type: :retain,
      position: 0,
      content: "",
      length: 0,
      timestamp: DateTime.utc_now()
    }
  end

  # Transform replace operation against insert operation
  defp transform_replace_insert(replace_op, insert_op) do
    cond do
      insert_op.position <= replace_op.position ->
        # Insert before replace - shift replace position right
        transformed_replace = %{
          replace_op
          | position: replace_op.position + String.length(insert_op.content)
        }

        {transformed_replace, insert_op}

      insert_op.position >= replace_op.position + replace_op.deleted_length ->
        # Insert after replace region - no change to replace
        {replace_op, insert_op}

      true ->
        # Insert within replace region - keep replace position same
        {replace_op, insert_op}
    end
  end

  # Transform replace operation against delete operation
  defp transform_replace_delete(replace_op, delete_op) do
    delete_end = delete_op.position + delete_op.length
    replace_end = replace_op.position + replace_op.deleted_length

    cond do
      delete_end <= replace_op.position ->
        # Delete completely before replace - shift replace position back
        transformed_replace = %{replace_op | position: replace_op.position - delete_op.length}
        {transformed_replace, delete_op}

      delete_op.position >= replace_end ->
        # Delete completely after replace - adjust delete position for replace's length change
        length_diff = String.length(replace_op.content) - replace_op.deleted_length
        transformed_delete = %{delete_op | position: delete_op.position + length_diff}
        {replace_op, transformed_delete}

      true ->
        # Delete overlaps with replace - complex case, for simplicity keep replace unchanged
        {replace_op, delete_op}
    end
  end

  # Transform two replace operations
  defp transform_replace_replace(op1, op2) do
    cond do
      op1.position + op1.deleted_length <= op2.position ->
        # op1 completely before op2 - adjust op2 position for op1's length change
        length_diff = String.length(op1.content) - op1.deleted_length
        transformed_op2 = %{op2 | position: op2.position + length_diff}
        {op1, transformed_op2}

      op2.position + op2.deleted_length <= op1.position ->
        # op2 completely before op1 - adjust op1 position for op2's length change
        length_diff = String.length(op2.content) - op2.deleted_length
        transformed_op1 = %{op1 | position: op1.position + length_diff}
        {transformed_op1, op2}

      true ->
        # Overlapping replaces - complex case, for simplicity keep both unchanged
        # In production, you might want timestamp-based resolution
        {op1, op2}
    end
  end

  @doc """
  Composes a sequence of operations into a single operation.
  """
  @spec compose_operations([operation()]) :: operation()
  def compose_operations([single_op]), do: single_op

  def compose_operations([op1, op2 | rest]) do
    composed = compose_two_operations(op1, op2)
    compose_operations([composed | rest])
  end

  defp compose_two_operations(op1, op2) do
    # This is a simplified composition - a full implementation would be more complex
    case {op1.type, op2.type} do
      {:insert, :insert} ->
        if op2.position == op1.position + String.length(op1.content) do
          # Adjacent inserts can be combined
          %{op1 | content: op1.content <> op2.content, length: op1.length + op2.length}
        else
          # Non-adjacent, can't easily compose
          op2
        end

      {:delete, :delete} ->
        if op2.position == op1.position do
          # Adjacent deletes can be combined
          %{op1 | length: op1.length + op2.length}
        else
          op2
        end

      _ ->
        # For other combinations, return the second operation
        op2
    end
  end

  # Helper function to split string at Unicode-safe position
  defp split_at_position(string, position) do
    if position == 0 do
      {"", string}
    else
      String.split_at(string, position)
    end
  end

  @doc """
  Validates an operation structure.
  """
  @spec valid_operation?(map()) :: boolean()
  def valid_operation?(%{type: type, position: pos, content: content, length: length})
      when type in [:insert, :delete, :retain] and
             is_integer(pos) and pos >= 0 and
             is_binary(content) and
             is_integer(length) and length >= 0 do
    true
  end

  def valid_operation?(_), do: false
end
