defmodule CheckerMal.Backend.EntryPoint do
  # TODO: check Application for a list enabled backends
  # TODO: construct function calls based on atoms
  # This uses the 'main' function should be called 
  #
  # This should use one of the backend as the 'source' for IDs,
  # and then send the computed structs to write back to one or more backends,
  # if any structs were returned from the update process
  #
  # Any backend receives 'added' and 'removed' as part of the
  # response structs for any updates, so changes made while waiting for
  # results are kept, they won't get overwritten

  def read(type) do
    # TODO: do, for each rating
    source_backend = Application.get_env(:checker_mal, :source_backend, :txt)

    apply(
      get_backend_module(source_backend),
      :read,
      [type, :sfw]
    )
  end

  def get_backend_module(backend_atom) when is_atom(backend_atom) do
    backend_module_name =
      backend_atom
      |> Atom.to_string()
      |> String.capitalize()

    module_name = "Elixir.CheckerMal.Backend.#{backend_module_name}"

    mod_atom =
      try do
        String.to_existing_atom(module_name)
      rescue
        ArgumentError ->
          String.to_atom(module_name)
      end

    {:module, module} = Code.ensure_loaded(mod_atom)
    module
  end
end
