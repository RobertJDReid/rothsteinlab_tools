json.array!(@excluded_colonies) do |excluded_colony|
  json.extract! excluded_colony, :experiment_id, :experiment_raw_dataset_id, :row, :column
  json.url excluded_colony_url(excluded_colony, format: :json)
end
