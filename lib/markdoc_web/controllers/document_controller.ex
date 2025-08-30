defmodule MarkdocWeb.DocumentController do
  use MarkdocWeb, :controller

  alias Markdoc.Documents

  def download(conn, %{"id" => document_id}) do
    case Documents.get_document(document_id) do
      {:ok, document} ->
        conn
        |> put_resp_content_type("text/markdown")
        |> put_resp_header("content-disposition", "attachment; filename=\"document-#{document.id}.md\"")
        |> send_resp(200, document.content)

      {:error, _reason} ->
        conn
        |> put_status(:not_found)
        |> put_view(html: MarkdocWeb.ErrorHTML, json: MarkdocWeb.ErrorJSON)
        |> render(:"404")
    end
  end
end
