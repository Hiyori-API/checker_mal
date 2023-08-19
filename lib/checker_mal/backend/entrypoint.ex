defmodule CheckerMal.Backend.EntryPoint do
  # This should use one of the backend as the 'source' for IDs,
  # and then send the computed structs to write back to one or more backends,
  # if any structs were returned from the update process
  #
  # Any backend receives 'added' and 'removed' as part of the
  # response structs for any updates, so changes made while waiting for
  # results are kept, they won't get overwritten

  @default_source :txt
  @default_backends [:txt]

  @source_backend Application.compile_env(:checker_mal, :source_backend, @default_source)

  def read(type, rating) do
    apply(
      get_backend_module(@source_backend),
      :read,
      [type, rating]
    )
  end

  @write_backends Application.compile_env(:checker_mal, :enabled_backends, @default_backends)
  # receives one or more feed items to write back to the file
  # reads incase any other changes have been made manually
  # in the interim (while requesting)
  def write(changed_structs, type, rating) when is_list(changed_structs) do
    if length(changed_structs) > 0 do
      @write_backends
      |> Enum.map(fn backend_atom ->
        apply(
          get_backend_module(backend_atom),
          :write,
          [changed_structs, type, rating]
        )
      end)
    else
      {:ok, :no_changes_to_process}
    end
  end

  # gets and loads a module for a backend
  # e.g. CheckerMal.Backend.Txt from the :txt atom
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
