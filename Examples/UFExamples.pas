unit UFExamples;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls;

type
  TFDelphAIExamples = class(TForm)
    gbEasy: TGroupBox;
    gbClassification: TGroupBox;
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    gbReg: TGroupBox;
    Button4: TButton;
    GroupBox1: TGroupBox;
    Button5: TButton;
    Button6: TButton;
    GroupBox2: TGroupBox;
    Button7: TButton;
    Button8: TButton;
    GroupBox3: TGroupBox;
    GroupBox4: TGroupBox;
    Button9: TButton;
    GroupBox5: TGroupBox;
    Button11: TButton;
    GroupBox6: TGroupBox;
    Button13: TButton;
    GroupBox7: TGroupBox;
    Button15: TButton;
    Button10: TButton;
    Button12: TButton;
    gbClassificationModels: TGroupBox;
    Button14: TButton;
    Button16: TButton;
    Button17: TButton;
    GroupBox8: TGroupBox;
    Button18: TButton;
    Button19: TButton;
    Button20: TButton;
    GroupBox9: TGroupBox;
    Button21: TButton;
    Button22: TButton;
    Button23: TButton;
    GroupBox10: TGroupBox;
    Button24: TButton;
    Button25: TButton;
    Button26: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure Button9Click(Sender: TObject);
    procedure Button10Click(Sender: TObject);
    procedure Button12Click(Sender: TObject);
    procedure Button11Click(Sender: TObject);
    procedure Button13Click(Sender: TObject);
    procedure Button15Click(Sender: TObject);
    procedure Button14Click(Sender: TObject);
    procedure Button18Click(Sender: TObject);
    procedure Button16Click(Sender: TObject);
    procedure Button17Click(Sender: TObject);
    procedure Button19Click(Sender: TObject);
    procedure Button20Click(Sender: TObject);
    procedure Button21Click(Sender: TObject);
    procedure Button22Click(Sender: TObject);
    procedure Button23Click(Sender: TObject);
    procedure Button24Click(Sender: TObject);
    procedure Button25Click(Sender: TObject);
    procedure Button26Click(Sender: TObject);
  private

  public

  end;

var
  FDelphAIExamples: TFDelphAIExamples;

implementation

uses
  UEasyAI, UAISelector, UAITypes, UKNN, UDecisionTree, UNaiveBayes, URecommender,
  URidgeRegression, ULinearRegression, UDBSCAN, UKMeans, UMeanShift, Winapi.ShellAPI;

const
  PATH_SAMPLES = '..\..\';
  PATH_DATASETS = '..\..\..\Datasets\';

{$R *.dfm}

procedure ShowArray(const aArray: TArray<Integer>);
var
  Value: Integer;
  MessageText: string;
begin
  for Value in aArray do
  begin
    MessageText := MessageText + Value.ToString + ', ';
  end;

  if MessageText <> '' then
  begin
    SetLength(MessageText, Length(MessageText) - 2);
  end;

  ShowMessage(MessageText);
end;

procedure TFDelphAIExamples.Button10Click(Sender: TObject);
var
  vEasyAIClass: TEasyAIClassification;
begin
  vEasyAIClass := TEasyAIClassification.Create;
  try
    vEasyAIClass.LoadDataset(PATH_DATASETS + 'Breast Cancer.csv');
    vEasyAIClass.FindBestModel(PATH_SAMPLES + 'Trained Breast Cancer.json');
  finally
    vEasyAIClass.Free;
  end;
end;

procedure TFDelphAIExamples.Button11Click(Sender: TObject);
var
  vRegression: TAIRegressionSelector;
begin
  vRegression := TAIRegressionSelector.Create(PATH_DATASETS + 'Housing Price.csv');
  try
    vRegression.Models.AddKNN(3);
    vRegression.Models.AddKNN(7);
    vRegression.Models.AddKNN(11);
    vRegression.Models.AddKNN(17);
    vRegression.Models.AddKNN(35);
    vRegression.Models.AddLinearRegression;
    vRegression.Models.AddRidge(0.01);
    vRegression.Models.AddRidge(0.1);
    vRegression.Models.AddRidge(1);
    vRegression.Models.AddRidge(10);
    vRegression.Models.AddRidge(100);
    vRegression.RunTests(PATH_SAMPLES + 'RegressionResult.csv', PATH_SAMPLES + 'RegressionLog.txt');
  finally
    vRegression.Free;
  end;
end;

procedure TFDelphAIExamples.Button12Click(Sender: TObject);
var
  vEasyAIClass: TEasyAIClassification;
begin
  vEasyAIClass := TEasyAIClassification.Create;
  try
    vEasyAIClass.LoadDataset(PATH_DATASETS + 'Breast Cancer.csv'); // Only necessary if the best model requires a dataset to make predictions.
    vEasyAIClass.LoadFromFile(PATH_SAMPLES + 'Trained Breast Cancer.json');
    ShowMessage('First cancer is: ' + vEasyAIClass.Predict([12, 15.65, 76.95, 443.3, 0.09723, 0.07165, 0.04151, 0.01863, 0.2079, 0.05968, 0.2271, 1255, 1441, 16.16, 0.005969, 0.01812, 0.02007, 0.007027, 0.01972, 0.002607, 13.67, 24.9, 87.78, 567.9, 0.1377, 0.2003, 0.2267, 0.07632, 0.3379, 0.07924])); // benign
    ShowMessage('Second cancer is: ' + vEasyAIClass.Predict([16.13, 20.68, 108.1, 798.8, 117, 0.2022, 0.1722, 0.1028, 0.2164, 0.07356, 0.5692, 1073, 3854, 54.18, 0.007026, 0.02501, 0.03188, 0.01297, 0.01689, 0.004142, 20.96, 31.48, 136.8, 1315, 0.1789, 0.4233, 0.4784, 0.2073, 0.3706, 0.1142])); // malignant
  finally
    vEasyAIClass.Free;
  end;
end;

procedure TFDelphAIExamples.Button13Click(Sender: TObject);
var
  vRecommendation: TAIRecommendationSelector;
begin
  vRecommendation := TAIRecommendationSelector.Create(PATH_DATASETS + 'MovieLens-100k\user_item_matrix.csv');
  try
    vRecommendation.Models.AddItemItem(10, TDistanceMode.dmCosine);
    vRecommendation.Models.AddItemItem(10, TDistanceMode.dmEuclidean);
    vRecommendation.Models.AddItemItem(10, TDistanceMode.dmManhattan);
    vRecommendation.Models.AddItemItem(10, TDistanceMode.dmJaccard);
    vRecommendation.Models.AddItemItem(10, TDistanceMode.dmPearson);
    vRecommendation.RunTestsItemItem(PATH_SAMPLES + 'RecItemResult.csv', PATH_SAMPLES + 'RecItemLog.txt');
  finally
    vRecommendation.Free;
  end;
end;

procedure TFDelphAIExamples.Button14Click(Sender: TObject);
// uses in UKNN
var
  vKNN: TKNNClassification;
begin
  vKNN := TKNNClassification.Create(PATH_DATASETS + 'Iris.csv', 3, False);
  try
    ShowMessage(vKNN.Predict([6.3, 3.3, 4.7, 1.6]));
  finally
    vKNN.Free;
  end;
end;

procedure TFDelphAIExamples.Button15Click(Sender: TObject);
var
  vRecommendation: TAIRecommendationSelector;
begin
  vRecommendation := TAIRecommendationSelector.Create(PATH_DATASETS + 'MovieLens-100k\user_item_matrix.csv');
  try
    vRecommendation.Models.AddUserUser(3, 5, amMode, TDistanceMode.dmCosine);
    vRecommendation.Models.AddUserUser(3, 5, amWeightedAverage, TDistanceMode.dmCosine);
    vRecommendation.Models.AddUserUser(3, 5, amSimpleSum, TDistanceMode.dmCosine);

    vRecommendation.Models.AddUserUser(3, 5, amMode, TDistanceMode.dmEuclidean);
    vRecommendation.Models.AddUserUser(3, 5, amWeightedAverage, TDistanceMode.dmEuclidean);
    vRecommendation.Models.AddUserUser(3, 5, amSimpleSum, TDistanceMode.dmEuclidean);
    vRecommendation.RunTestsUserUser(PATH_SAMPLES + 'RecUserResult.csv', PATH_SAMPLES + 'RecUserLog.txt');
  finally
    vRecommendation.Free;
  end;
end;

procedure TFDelphAIExamples.Button16Click(Sender: TObject);
// uses in UDecisionTree
var
  vTree: TDecisionTree;
begin
  vTree := TDecisionTree.Create(5, scGini);
  try
    vTree.Train(PATH_DATASETS + 'Iris.csv', False);
    ShowMessage(vTree.Predict([6.3, 3.3, 4.7, 1.6]));
  finally
    vTree.Free;
  end;
end;

procedure TFDelphAIExamples.Button17Click(Sender: TObject);
// uses in UNaiveBayes
var
  vNaiveB: TGaussianNaiveBayes;
begin
  vNaiveB := TGaussianNaiveBayes.Create;
  try
    vNaiveB.Train(PATH_DATASETS + 'Iris.csv', False);
    ShowMessage(vNaiveB.Predict([6.3, 3.3, 4.7, 1.6]));
  finally
    vNaiveB.Free;
  end;
end;

procedure TFDelphAIExamples.Button18Click(Sender: TObject);
// uses in UKNN
var
  vKNN: TKNNRegression;
begin
  vKNN := TKNNRegression.Create(PATH_DATASETS + 'Housing Price.csv', 3);
  try
    ShowMessage('House price: ' + FormatCurr('##0.00', vKNN.Predict([2459, 1, 1, 1964, 3.1047807561601664, 0, 4])));
  finally
    vKNN.Free;
  end;
end;

procedure TFDelphAIExamples.Button19Click(Sender: TObject);
// uses in ULinearRegression
var
  vLinearReg: TLinearRegression;
begin
  vLinearReg := TLinearRegression.Create;
  try
    vLinearReg.Train(PATH_DATASETS + 'Housing Price.csv', True);
    ShowMessage('House price: ' + FormatCurr('##0.00', vLinearReg.Predict([2459, 1, 1, 1964, 3.1047807561601664, 0, 4])));
  finally
    vLinearReg.Free;
  end;
end;

procedure TFDelphAIExamples.Button1Click(Sender: TObject);
var
  vEasyAIClass: TEasyAIClassification;
begin
  vEasyAIClass := TEasyAIClassification.Create;
  try
    vEasyAIClass.LoadDataset(PATH_DATASETS + 'Iris.csv', False);
    vEasyAIClass.FindBestModel(PATH_SAMPLES + 'Trained Iris.json');
  finally
    vEasyAIClass.Free;
  end;
end;

procedure TFDelphAIExamples.Button20Click(Sender: TObject);
// uses in URidgeRegression
var
  vRidge: TRidgeRegression;
begin
  vRidge := TRidgeRegression.Create(0.1);
  try
    vRidge.Train(PATH_DATASETS + 'Housing Price.csv', True);
    ShowMessage('House price: ' + FormatCurr('##0.00', vRidge.Predict([2459, 1, 1, 1964, 3.1047807561601664, 0, 4])));
  finally
    vRidge.Free;
  end;
end;

procedure TFDelphAIExamples.Button21Click(Sender: TObject);
// uses in UKMeans
begin
  ShowArray(KMeans(PATH_DATASETS + 'Iris-Clustering.csv', 3, 500, 42));
end;

procedure TFDelphAIExamples.Button22Click(Sender: TObject);
// uses in UMeanShift
begin
  ShowArray(MeanShift(PATH_DATASETS + 'Iris-Clustering.csv', 0.2, 0.1));
end;

procedure TFDelphAIExamples.Button23Click(Sender: TObject);
// uses in UDBSCAN
begin
  ShowArray(DBSCAN(PATH_DATASETS + 'Iris-Clustering.csv', 0.1, 5));
end;

procedure TFDelphAIExamples.Button24Click(Sender: TObject);
// uses in URecommender
var
  vRecommender: TRecommender;
begin
  vRecommender := TRecommender.Create(PATH_DATASETS + 'MovieLens-100k\user_item_matrix.csv', 5, 20, TUserScoreAggregationMethod.amWeightedAverage, dmCosine, True, False);
  try
    ShowArray(vRecommender.RecommendFromUser(105));
    ShowArray(vRecommender.RecommendFromItem(4070));
  finally
    vRecommender.Free;
  end;
end;

procedure TFDelphAIExamples.Button25Click(Sender: TObject);
begin
  ShowMessage('In development');
end;

procedure TFDelphAIExamples.Button26Click(Sender: TObject);
begin
  ShellExecute(0, 'open', PChar('https://delphai.gitbook.io/delphai'), nil, nil, SW_SHOWNORMAL);
end;

procedure TFDelphAIExamples.Button2Click(Sender: TObject);
var
  vEasyAIClass: TEasyAIClassification;
begin
  vEasyAIClass := TEasyAIClassification.Create;
  try
    vEasyAIClass.LoadDataset(PATH_DATASETS + 'Iris.csv', False); // Only necessary if the best model requires a dataset to make predictions.
    vEasyAIClass.LoadFromFile(PATH_SAMPLES + 'Trained Iris.json');
    ShowMessage('Flower species: ' + vEasyAIClass.Predict([6.3, 3.3, 4.7, 1.6]));
  finally
    vEasyAIClass.Free;
  end;
end;

procedure TFDelphAIExamples.Button3Click(Sender: TObject);
var
  vEasyAIClass: TEasyAIRegression;
begin
  vEasyAIClass := TEasyAIRegression.Create;
  try
    vEasyAIClass.LoadDataset(PATH_DATASETS + 'Housing Price.csv');
    vEasyAIClass.FindBestModel(PATH_SAMPLES + 'trainedFile-Housing-price.json')
  finally
    vEasyAIClass.Free;
  end;
end;

procedure TFDelphAIExamples.Button4Click(Sender: TObject);
var
  vEasyAIClass: TEasyAIRegression;
begin
  vEasyAIClass := TEasyAIRegression.Create;
  try
    vEasyAIClass.LoadDataset(PATH_DATASETS + 'Housing Price.csv'); // Only necessary if the best model requires a dataset to make predictions.
    vEasyAIClass.LoadFromFile(PATH_SAMPLES + 'trainedFile-Housing-price.json');
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

procedure TFDelphAIExamples.Button5Click(Sender: TObject);
var
  vEasyAIClass: TEasyAIRecommendationFromItem;
begin
  vEasyAIClass := TEasyAIRecommendationFromItem.Create(10);
  try
    vEasyAIClass.LoadDataset(PATH_DATASETS + 'MovieLens-100k\user_item_matrix.csv', False);
    vEasyAIClass.FindBestModel(PATH_SAMPLES + 'trainedFile-rec-item.json');
  finally
    vEasyAIClass.Free;
  end;
end;

procedure TFDelphAIExamples.Button6Click(Sender: TObject);
var
  vEasyAIClass: TEasyAIRecommendationFromItem;
begin
  vEasyAIClass := TEasyAIRecommendationFromItem.Create(10);
  try
    vEasyAIClass.LoadDataset(PATH_DATASETS + 'MovieLens-100k\user_item_matrix.csv', False);
    vEasyAIClass.LoadFromFile(PATH_SAMPLES + 'trainedFile-rec-item.json');
    ShowArray(vEasyAIClass.RecommendItem(4070));
  finally
    vEasyAIClass.Free;
  end;
end;

procedure TFDelphAIExamples.Button7Click(Sender: TObject);
var
  vEasyAIClass: TEasyAIRecommendationFromUser;
begin
  vEasyAIClass := TEasyAIRecommendationFromUser.Create(10);
  try
    vEasyAIClass.LoadDataset(PATH_DATASETS + 'MovieLens-100k\user_item_matrix.csv', False);
    vEasyAIClass.FindBestModel(PATH_SAMPLES + 'trainedFile-rec-user.json');
  finally
    vEasyAIClass.Free;
  end;
end;

procedure TFDelphAIExamples.Button8Click(Sender: TObject);
var
  vEasyAIClass: TEasyAIRecommendationFromUser;
begin
  vEasyAIClass := TEasyAIRecommendationFromUser.Create(10);
  try
    vEasyAIClass.LoadDataset(PATH_DATASETS + 'MovieLens-100k\user_item_matrix.csv', False);
    vEasyAIClass.LoadFromFile(PATH_SAMPLES + 'trainedFile-rec-user.json');
    ShowArray(vEasyAIClass.RecommendItem(105));
  finally
    vEasyAIClass.Free;
  end;
end;

procedure TFDelphAIExamples.Button9Click(Sender: TObject);
var
  vClassification: TAIClassificationSelector;
begin
  vClassification := TAIClassificationSelector.Create(PATH_DATASETS + 'Breast Cancer.csv');
  try
    vClassification.Models.AddKNN(1);
    vClassification.Models.AddKNN(7);
    vClassification.Models.AddKNN(15);
    vClassification.Models.AddKNN(21);
    vClassification.Models.AddTree(5, scGini);
    vClassification.Models.AddNaiveBayes;
    vClassification.RunTests(PATH_SAMPLES + 'ClassificationResult.csv', PATH_SAMPLES + 'ClassificationLog.txt');
  finally
    vClassification.Free;
  end;
end;

end.

