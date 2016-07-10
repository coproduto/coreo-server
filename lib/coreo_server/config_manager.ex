defmodule CoreoServer.ConfigManager do
  use GenServer

  alias CoreoServer.Config

  import Ecto
  import Ecto.Changeset
  import Ecto.Query

###Default configs
  def default_config do
    %{ "is_active" => true, "lock_new_words" => true, "video" => "" }
  end

###Client API
  def start_link(name) do
    #Check if the database has an active config
    #If it has, use its settings
    #If not, use defaults
    IO.puts "Starting config manager"
    
    initial_config = create_initial_config

    GenServer.start_link(__MODULE__, initial_config, name: name)
  end

  def get(server, name) do
    GenServer.call(server, {:get, name})
  end

  def toggle(server, name) do
    GenServer.cast(server, {:toggle, name})
  end

  def set(server, name, value) do
    GenServer.cast(server, {:set, name, value})
  end

###Server implementation
  def handle_call({:get, name}, _from, config) do
    {:reply, Map.fetch(config, name), config}
  end

  def handle_cast({:toggle, name}, config) do
    if Map.has_key?(config, name) do
      {_, previous_value} = Map.fetch(config, name)
      
      params = %{ name => (not previous_value) }
      IO.puts "parameters"
      IO.inspect params
      previous_config = get_config

      changeset = Config.changeset(previous_config, params)
      IO.puts "changes"
      IO.inspect changeset
      
      result = CoreoServer.Repo.transaction( fn ->
	CoreoServer.Repo.update!(changeset)
      end)
      case result do
	{:ok, new_config} ->
	  {:noreply, new_config}
	{:error, _changeset} ->
	  {:noreply, config}
      end
    end
  end

  def handle_cast({:set, name, value}, config) do
    IO.puts "Received cast - request to set #{name} to #{value}"
    if Map.has_key?(config, name) do
      new_config = Map.put(config, name, value)
      IO.puts "new config"
      IO.inspect new_config

      params = %{ name => value }
      IO.puts "parameters"
      IO.inspect params

      previous_config = get_config
      IO.puts "previous"
      IO.inspect previous_config

      changeset = Config.changeset(previous_config, params)
      IO.puts "changes"
      IO.inspect changeset

      result = CoreoServer.Repo.transaction(fn ->
	CoreoServer.Repo.update!(changeset)
      end)

      IO.puts "result"
      IO.inspect result

      case result do
	{:ok, _res} ->
	  if name == :video do
	    CoreoServer.UpdateChannel.broadcast_new_video(value)
	  end
	  {:noreply, new_config}
	{:error, _changeset} ->
	  {:noreply, config}
      end
    else
      {:noreply, config}
    end
  end
  
###Database management
  def create_initial_config do
    how_many_configs = from c in Config,
    where: c.is_active == true,
    select: count(c.id)

    result = CoreoServer.Repo.one(how_many_configs)
    if result <= 0 do
	insert_default_config
    else
	select_newest_config
    end
  end
  
  def get_config do
    query = from c in Config,
    where: c.is_active == true

    CoreoServer.Repo.one!(query)
  end

  def select_newest_config do
    newest_query = from c in Config,
    order_by: [desc: c.inserted_at],
    limit: 1

    newest = CoreoServer.Repo.one(newest_query)

    old_ones_query = from c in Config,
    where: c.id != ^newest.id

    CoreoServer.Repo.update_all(old_ones_query, set: [is_active: false])
    IO.inspect newest.video
    
    newest
  end

  def insert_default_config do
    changeset = Config.changeset(%Config{}, default_config)

    case CoreoServer.Repo.insert(changeset) do
      {:ok, config} ->
	config
      {:error, _changeset} ->
	:error
    end
  end
end
