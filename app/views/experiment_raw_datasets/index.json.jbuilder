json.array!(@experiment_raw_datasets) do |experiment_raw_dataset|
  json.extract! experiment_raw_dataset, 
  json.url experiment_raw_dataset_url(experiment_raw_dataset, format: :json)
end
