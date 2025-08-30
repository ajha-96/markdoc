defmodule MarkdocWeb.Components.ThemeSelector do
  use MarkdocWeb, :html

  def component(assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <div tabindex="0" role="button" class="btn m-1">
        Theme
        <svg
          width="12px"
          height="12px"
          class="h-2 w-2 fill-current opacity-60 inline-block"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 2048 2048"
        >
          <path d="M1799 349l242 241-1017 1017L7 590l242-241 775 775 775-775z" />
        </svg>
      </div>
      <ul
        tabindex="0"
        class="dropdown-content z-[1] p-2 shadow-2xl bg-base-300 rounded-box w-52"
      >
        <li>
          <span class="font-bold text-primary-focus">Light Themes</span>
        </li>
        <%= for theme <- themes().light do %>
          <li>
            <button
              class="btn btn-ghost"
              phx-click={JS.dispatch("phx:set-theme")}
              data-phx-theme={theme}
            >
              <%= theme %>
            </button>
          </li>
        <% end %>
        <li>
          <span class="font-bold text-primary-focus">Dark Themes</span>
        </li>
        <%= for theme <- themes().dark do %>
          <li>
            <button
              class="btn btn-ghost"
              phx-click={JS.dispatch("phx:set-theme")}
              data-phx-theme={theme}
            >
              <%= theme %>
            </button>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  defp themes do
    %{
      light: [
        "light",
        "cupcake",
        "bumblebee",
        "emerald",
        "corporate",
        "retro",
        "cyberpunk",
        "valentine",
        "garden",
        "lofi",
        "pastel",
        "fantasy",
        "wireframe",
        "cmyk",
        "autumn",
        "acid",
        "lemonade",
        "winter",
        "nord",
        "caramellatte",
        "silk"
      ],
      dark: [
        "dark",
        "synthwave",
        "halloween",
        "forest",
        "aqua",
        "black",
        "luxury",
        "dracula",
        "business",
        "night",
        "coffee",
        "dim",
        "sunset",
        "abyss"
      ]
    }
  end
end
