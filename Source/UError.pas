unit UError;

interface

const
  ERROR_INPUT_SIZE_DIFFERENT = 'The input array size does not match the expected size of the Dataset. Please check and adjust the input data.';
  ERROR_MODEL_NOT_TRAINED = 'The model has not been trained yet. Please ensure the model is trained before making predictions or validations.';
  ERROR_EMPTY_Dataset_EASY_TRAIN = 'The Dataset is not loaded. Use the "LoadDataset" method before find the best model.';
  ERROR_EMPTY_Dataset_EASY_PREDICT = 'The Dataset is not loaded, and the best model requires it. Use the "LoadDataset" method before predict.';


implementation

end.
