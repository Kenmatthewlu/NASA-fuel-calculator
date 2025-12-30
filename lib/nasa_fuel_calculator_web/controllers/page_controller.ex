defmodule NasaFuelCalculatorWeb.PageController do
  use NasaFuelCalculatorWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
