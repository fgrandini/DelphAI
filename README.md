# DelphAI

**DelphAI** is a Delphi component inspired by Scikit-learn, designed to simplify the development of **regression**, **classification**, **recommendation**, and **clustering** solutions.

Whether you're a beginner or an experienced Machine Learning practitioner, DelphAI makes the process simple and efficient, allowing you to focus on results rather than complex implementation.

---

## Key Features

- **Regression**: Model and predict values based on attributes.
- **Clustering**: Identify patterns in your data with clustering algorithms.
- **Classification**: Categorize data into distinct classes.
- **Recommendation**: Build recommendation systems for items and users.
- **EasyAI**: A module for beginners that automates the entire process:
  - Selects the best model for the problem.
  - Performs validation tests.
  - Saves configurations (parameters) in files for future reuse.

---

## Full Documentation

For technical details, classes, functions, and usage examples, visit our official documentation:  
📚 **[DelphAI Documentation](https://delphai.gitbook.io/delphai)**

---

## How to Use

### 1. Install the component
Clone the repository and add the files to your library path or Delphi project. More details on how to do this can be found **[in the documentation](https://delphai.gitbook.io/delphai/visao-geral/instalacao)**.

### 2. Use EasyAI to find the best model for you (Regression example):

```delphi
uses
  UEasyAI;
  
procedure TrainModel;
var
  vEasyAIClass: TEasyAIRegression;
begin
  vEasyAIClass := TEasyAIRegression.Create;
  try
    vEasyAIClass.LoadDataset('C:\DelphAI\DelphAI\Datasets\Housing Price.csv');
    vEasyAIClass.FindBestModel('C:\Example\trainedFile-Housing-price');
  finally
    vEasyAIClass.Free;
  end;
end;
```
### 3. Load the generated file to make predictions:

```delphi
uses
  UEasyAI;
  
procedure ShowPredictedHousesPrice;
var
  vEasyAIClass: TEasyAIRegression;
begin
  vEasyAIClass := TEasyAIRegression.Create;
  try
    vEasyAIClass.LoadDataset('C:\DelphAI\DelphAI\Datasets\Housing Price.csv'); // Only required if alerted that the best model needs the dataset.
    vEasyAIClass.LoadFromFile('C:\Example\trainedFile-Housing-price');
    // To predict a house with the same properties the model was trained on:
    // Square_Footage = 1
    // Num_Bedrooms = 1
    // Num_Bathrooms = 1
    // Year_Built = 1964
    // Lot_Size = 3.1047807561601664
    // Garage_Size = 0
    // Neighborhood_Quality = 4
    ShowMessage('House price: ' + FormatCurr('##0.00', vEasyAIClass.Predict([2459, 1, 1, 1964, 3.1047807561601664, 0, 4])));
  finally
    vEasyAIClass.Free;
  end;
end;
```

---

## Contributions

Contributions are welcome! Feel free to open issues or submit pull requests for improvements.

---

## License

This project is licensed under the **LGPL License**. See the `LICENSE` file for more details.