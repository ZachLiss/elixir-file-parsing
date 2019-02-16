defmodule Streamers do
  @moduledoc """
  Documentation for Streamers.
  """

  @doc """
    Find streaming index file in the given directory.
    """
  def find_index(directory) do
    files = Path.join(directory, "*.m3u8")
    Enum.find Path.wildcard(files), &is_index?(&1)
  end

  def is_index?(file) do
    File.open! file, fn(pid) ->
      IO.read(pid, 25) == "#EXTM3U\n#EXT-X-STREAM-INF"
    end
  end

  @doc """
    Extract list of of stream files for given index file.
    """
  def extract_m3u8(index_file) do
    File.open! index_file, fn(pid) ->
      # Discards #EXTM3U
      IO.read(pid, :line)
      do_extract_m3u8(pid, Path.dirname(index_file), [])
    end
  end

  defp do_extract_m3u8(pid, dir, acc) do
    case IO.read(pid, :line) do
      :eof -> Enum.reverse(acc)
      stream_inf ->
        file_name = IO.read(pid, :line)
        do_extract_m3u8(pid, dir, stream_inf, file_name, acc)
    end
  end

  defp do_extract_m3u8(pid, dir, stream_inf, file_name, acc) do
    # #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=110000
    << "#EXT-X-STREAM-INF:PROGRAM-ID=", program_id, ",BANDWIDTH=", bandwidth :: binary >> = stream_inf
    program_id = String.to_integer(<<program_id>>)
    { bandwidth, _trash } = Integer.parse(bandwidth)
    path = Path.join(dir, String.trim(file_name, "\n"))
    record = %{program_id: program_id, path: path, bandwidth: bandwidth, ts_files: []}
    do_extract_m3u8(pid, dir, [record|acc])
  end

  @doc"""
    Process M3U8 records to get ts_files
    """
  def process_m3u8(m3u8s) do
    Enum.map m3u8s, &do_parallel_process_m3u8(&1, self())
    do_collect_m3u8(length(m3u8s), [])
  end

  defp do_collect_m3u8(0, acc), do: acc

  defp do_collect_m3u8(count, acc) do
    receive do
      { :m3u8, updated_m3u8 } ->
        do_collect_m3u8(count - 1, [updated_m3u8|acc])
    end
  end

  defp do_parallel_process_m3u8(m3u8, parent_pid) do
    spawn(fn ->
      updated_m3u8 = do_process_m3u8(m3u8)
      send parent_pid, { :m3u8, updated_m3u8 }
    end)
  end

  defp do_process_m3u8(%{ path: path } = m3u8) do
    File.open! path, fn(pid) ->
      # discard first 2 lines
      IO.read(pid, :line)
      IO.read(pid, :line)
      %{m3u8 | ts_files: do_process_m3u8(pid, [])}
    end
  end

  defp do_process_m3u8(pid, acc) do
    case IO.read(pid, :line) do
      "#EXT-X-ENDLIST\n" -> Enum.reverse(acc)
      _extinf ->
        file = IO.read(pid, :line) |> String.trim("\n")
        do_process_m3u8(pid, [file|acc])
    end
  end
end
