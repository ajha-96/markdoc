defmodule MarkdocWeb.PageController do
  use MarkdocWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
