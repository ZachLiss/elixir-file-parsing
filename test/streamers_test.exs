defmodule StreamersTest do
  use ExUnit.Case
  doctest Streamers

	@index_file "test/fixtures/emberjs/9af0270acb795f9dcafb5c51b1907628.m3u8"

  test "find index file in a directory" do
    assert Streamers.find_index("test/fixtures/emberjs") == @index_file
  end

  test "returns nil for not available index file" do
    assert Streamers.find_index("test/fixtures/not_available") == nil
  end

  test "extracts m3u8 from index file" do
		m3u8s = Streamers.extract_m3u8(@index_file)
		assert Enum.at(m3u8s, 0) == %{program_id: 1, bandwidth: 110000, path: "test/fixtures/emberjs/8bda35243c7c0a7fc69ebe1383c6464c.m3u8", ts_files: []}
		assert length(m3u8s) == 5
  end

  test "extracts ts streams from m3u8 file" do
		m3u8s = @index_file |> Streamers.extract_m3u8 |> Streamers.process_m3u8
		assert length(Enum.at(m3u8s, 0).ts_files) == 510
  end
end
