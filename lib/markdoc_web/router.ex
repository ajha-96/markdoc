defmodule MarkdocWeb.Router do
  use MarkdocWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MarkdocWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MarkdocWeb do
    pipe_through :browser

    # Landing page - create new document
    live "/", DocumentLive.Index, :create

    # Join existing document with name entry
    live "/documents/:id", DocumentLive.Index, :join

    # Document editor
    live "/documents/:id/edit", DocumentLive.Edit, :edit

    get "/documents/:id/download", DocumentController, :download
  end

  # Other scopes may use custom stacks.
  # scope "/api", MarkdocWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:markdoc, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MarkdocWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
