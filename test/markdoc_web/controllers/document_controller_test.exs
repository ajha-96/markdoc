defmodule MarkdocWeb.DocumentControllerTest do
  use MarkdocWeb.ConnCase, async: true

  alias Markdoc.Documents

  setup do
    document_id = Documents.create_document()
    {:ok, document: Documents.get_document(document_id) |> elem(1)}
  end

  describe "download/2" do
    test "downloads the document content as a markdown file", %{conn: conn, document: document} do
      # Update the document with some content
      new_content = "# Test Document\n\nThis is a test."
      :ok = Documents.update_document_content(document.id, new_content)
      updated_doc = Documents.get_document(document.id) |> elem(1)

      conn = get(conn, ~p"/documents/#{updated_doc.id}/download")

      assert conn.status == 200
      assert get_resp_header(conn, "content-disposition") == ["attachment; filename=\"document-#{updated_doc.id}.md\""]
      assert get_resp_header(conn, "content-type") == ["text/markdown; charset=utf-8"]
      assert conn.resp_body == new_content
    end

    test "returns 404 when document does not exist", %{conn: conn} do
      invalid_id = "00000000-0000-0000-0000-000000000000"
      conn = get(conn, ~p"/documents/#{invalid_id}/download")
      assert conn.status == 404
    end
  end
end
