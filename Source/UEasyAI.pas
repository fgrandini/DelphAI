unit UEasyAI;

interface

uses
  UAISelector,
  Winapi.Windows,
  Data.DB,
  UAITypes,
  Vcl.Graphics,
  System.Classes,
  URecommender;

type

  TEasyModelNN = (em32x32Resnet20, em224x224Resnet18);

  TEasyTestingMode = (tmFast, tmStandard, tmExtensive);

  TEasyAIClassification = class
  private
    FDataset : TAIDatasetClassification;
    FNormalizationRange : TNormalizationRange;
    FModel : TObject;
  public
    constructor Create;
    procedure LoadDataset(aDataSet : String; aHasHeader : Boolean = True); overload;
    procedure LoadDataset(aDataSet : TDataSet); overload;
    procedure LoadFromFile(aPath : String);
    procedure FindBestModel(aPathResultFile: String; aMode : TEasyTestingMode = tmStandard; aMaxThreads : Integer = 0; aCsvResultModels : String = ''; aLogFile : String = '');
    function Predict(aSample : TAISampleAtr) : String;
    destructor Destroy; override;
  end;

  TEasyAIRegression = class
  private
    FDataset : TAIDatasetRegression;
    FModel : TObject;
    FNormalizationRange : TNormalizationRange;
  public
    procedure LoadDataset(aDataSet : String; aHasHeader : Boolean = True); overload;
    procedure LoadDataset(aDataSet : TDataSet); overload;
    procedure LoadFromFile(aPath : String);
    procedure FindBestModel(aPathResultFile: String; aMode : TEasyTestingMode = tmStandard; aMaxThreads : Integer = 0; aCsvResultModels : String = ''; aLogFile : String = '');
    function Predict(aSample : TAISampleAtr) : Double;
    destructor Destroy; override;
  end;

  TEasyAIRecommendationFromItem = class
  private
    FDataset : TAIDatasetRecommendation;
    FModel : TRecommender;
    FNormalizationRange : TNormalizationRange;
    FItemsToRecommendCount : Integer;
  public
    constructor Create(aItemsToRecommendCount : Integer) ;
    destructor Destroy; override;
    procedure LoadDataset(aDataSet : String; aHasHeader : Boolean = True); overload;
    procedure LoadDataset(aDataSet : TDataSet); overload;
    procedure LoadFromFile(aPath : String);
    procedure FindBestModel(aPathResultFile: String; aMode : TEasyTestingMode = tmStandard; aMaxThreads : Integer = 0; aCsvResultModels : String = ''; aLogFile : String = '');
    function RecommendItem(aFromItemSample : TAISampleAtr) : TArray<Integer>; overload;
    function RecommendItem(aFromItemID : Integer) : TArray<Integer>; overload;
  end;

  TEasyAIRecommendationFromUser = class
  private
    FDataset : TAIDatasetRecommendation;
    FModel : TRecommender;
    FNormalizationRange : TNormalizationRange;
    FItemsToRecommendCount : Integer;
  public
    constructor Create(aItemsToRecommendCount : Integer) ;
    destructor Destroy; override;
    procedure LoadDataset(aDataSet : String; aHasHeader : Boolean = True); overload;
    procedure LoadDataset(aDataSet : TDataSet); overload;
    procedure LoadFromFile(aPath : String);
    procedure FindBestModel(aPathResultFile: String; aMode : TEasyTestingMode = tmStandard; aMaxThreads : Integer = 0; aCsvResultModels : String = ''; aLogFile : String = '');
    function RecommendItem(aFromUserSample : TAISampleAtr) : TArray<Integer>; overload;
    function RecommendItem(aFromUserID : Integer) : TArray<Integer>; overload;
  end;

  procedure ShowMessageNeedDataset(aNeed : Boolean = True);
  function RemoveDuplicates(aInputArray: TArray<Integer>): TArray<Integer>;
  function CalculaKNNValores(aSamples: Integer; aMode : TEasyTestingMode = tmFast): TArray<Integer>;

implementation
uses
  {$IF FMX.Types.FireMonkeyVersion >= 0}
  FMX.DialogService,
  {$ELSE}
  VCL.Dialogs,
  {$ENDIF}
  UAuxGlobal,
  System.SysUtils,
  System.JSON,
  System.IOUtils,
  UDecisionTree,
  UKNN,
  UNaiveBayes,
  ULinearRegression,
  URidgeRegression,
  System.Math,
  System.Generics.Collections,
  System.Types,
  UError,
  UAIModel;

{ TEasyAIClassification }

constructor TEasyAIClassification.Create;
begin

end;

procedure ShowMessageNeedDataset(aNeed : Boolean = True);
begin
  if aNeed then begin
    {$IF FMX.Types.FireMonkeyVersion >= 0}
      TDialogService.ShowMessage('Warning: The best model needs to load the dataset before predicting!');
    {$ELSE}
      ShowMessage('Warning: The best model needs to load the dataset before predicting!');
    {$ENDIF}
  end else begin
    {$IF FMX.Types.FireMonkeyVersion >= 0}
      TDialogService.ShowMessage('NO need to load the dataset to predict.');
    {$ELSE}
      ShowMessage('NO need to load the dataset to predict.');
    {$ENDIF}
  end;
end;

function RemoveDuplicates(aInputArray: TArray<Integer>): TArray<Integer>;
var
  vHashSet: TDictionary<Integer, Boolean>;
  vNumber: Integer;
  vUniqueList: TList<Integer>;
begin
  vHashSet := TDictionary<Integer, Boolean>.Create;
  vUniqueList := TList<Integer>.Create;
  try
    for vNumber in aInputArray do begin
      if not vHashSet.ContainsKey(vNumber) then
      begin
        vHashSet.Add(vNumber, True);
        vUniqueList.Add(vNumber);
      end;
    end;
    Result := vUniqueList.ToArray;
  finally
    vHashSet.Free;
    vUniqueList.Free;
  end;
end;

function CalculaKNNValores(aSamples: Integer; aMode : TEasyTestingMode = tmFast): TArray<Integer>;
var
  K, i, vIncrease : Integer;
  vTempArray : TArray<Integer>;
begin
  SetLength(Result, 10);

  K := Trunc(Sqrt(aSamples) / 2);
  if K mod 2 = 0 then
    Inc(K);

  Result[4] := K;

  vIncrease := Trunc(0.2 * K);
  if vIncrease < 2 then begin
    vIncrease := 2;
  end;
  if vIncrease mod 2 <> 0 then
    Inc(vIncrease);

  for i := 3 downto 0 do
    Result[i] := Result[i + 1] - vIncrease;

  for i := 5 to 9 do
    Result[i] := Result[i - 1] + vIncrease;

  for i := 0 to 9 do begin
    if Result[i] mod 2 = 0 then begin
      Dec(Result[i]);
    end;
    if Result[i] < 1 then begin
      Result[i] := 1;
    end;
  end;

  for i := 0 to High(Result) do begin
    if Result[i] >= aSamples then begin
      Result[i] := aSamples-2;
    end;
  end;

  if Result[0] > 3 then begin
    Result[0] := 3;
  end;

  vTempArray := Copy(Result);

  if aMode = tmFast then begin
    SetLength(Result, 4);
    Result[0] := vTempArray[0];
    Result[1] := vTempArray[2];
    Result[2] := vTempArray[4];
    Result[3] := vTempArray[9];
  end else if aMode = tmStandard then begin
    Result[0] := vTempArray[0];
    Result[1] := vTempArray[1];
    Result[2] := vTempArray[3];
    Result[2] := vTempArray[4];
    Result[3] := vTempArray[5];
    Result[4] := vTempArray[7];
    Result[5] := vTempArray[9];
    SetLength(Result, 6)
  end;
  Result := RemoveDuplicates(Result);
end;

destructor TEasyAIClassification.Destroy;
begin
  FModel.Free;
  inherited;
end;

procedure TEasyAIClassification.FindBestModel(aPathResultFile: String; aMode : TEasyTestingMode = tmStandard; aMaxThreads : Integer = 0; aCsvResultModels : String = ''; aLogFile : String = '');
var
  vBestIndex,
  vNumSamples,
  i : Integer;
  vClassification : TAIClassificationSelector;
  vMoreAccuracy : Double;
  vBestModel : TAIClassificationTest;
  vJsonObj, vParamsObj: TJSONObject;
  vJSONString: string;
  vFileStream: TFileStream;
  vBytes: TBytes;
begin
  vNumSamples := Length(FDataset);
  if Length(FDataset) <= 1 then begin
    raise Exception.Create(ERROR_EMPTY_Dataset_EASY_TRAIN);
  end;
  vClassification := TAIClassificationSelector.Create(FDataset, FNormalizationRange);
  try
    if aMode = tmStandard then begin
      vClassification.Models.AddTree(Round(Log2(vNumSamples)), scGini);
      vClassification.Models.AddTree(Round(Log2(vNumSamples)), scEntropy);
    end else if aMode = tmExtensive then begin
      vClassification.Models.AddTree(Round(Log2(vNumSamples) / 2), scGini);
      vClassification.Models.AddTree(Round(Log2(vNumSamples) / 2), scEntropy);

      vClassification.Models.AddTree(Round(Log2(vNumSamples)), scGini);
      vClassification.Models.AddTree(Round(Log2(vNumSamples)), scEntropy);

      vClassification.Models.AddTree(Round(Log2(vNumSamples) * 2), scGini);
      vClassification.Models.AddTree(Round(Log2(vNumSamples) * 2), scEntropy);
    end;

    for i in CalculaKNNValores(vNumSamples, aMode) do begin
      vClassification.Models.AddKNN(i);
    end;

    vClassification.Models.AddNaiveBayes;

    vClassification.RunTests(aCsvResultModels, aLogFile, aMaxThreads);

    vMoreAccuracy := 0;
    vBestIndex := 0;
    for i := 0 to vClassification.Models.LstModels.Count-1 do begin
      if vClassification.Models.LstModels[i].Accuracy > vMoreAccuracy then begin
        vBestIndex := i;
        vMoreAccuracy := vClassification.Models.LstModels[i].Accuracy;
      end;
    end;

    vJsonObj := TJSONObject.Create;
    try
      vBestModel := vClassification.Models.LstModels[vBestIndex];
      vJsonObj.AddPair('Precision', TJSONNumber.Create(vBestModel.Accuracy));
      if vBestModel is TAIClassificationModelKNN then begin
        ShowMessageNeedDataset;
        vJsonObj.AddPair('model', 'KNN');
        vParamsObj := TJSONObject.Create;
        vParamsObj.AddPair('K', TJSONNumber.Create(TAIClassificationModelKNN(vBestModel).K));
        vJsonObj.AddPair('parameters', vParamsObj);
      end else if vBestModel is TAIClassificationModelTree then begin
        ShowMessageNeedDataset(False);
        vJsonObj.AddPair('model', 'DecisionTree');
        vParamsObj := TJSONObject.Create;
        vParamsObj.AddPair('Structure', TAIClassificationModelTree(vBestModel).TreeToJSON);
        vJsonObj.AddPair('parameters', vParamsObj);
      end else if vBestModel is TAIClassificationModelNaive then begin
        ShowMessageNeedDataset(False);
        vJsonObj.AddPair('model', 'GaussianNaive');
        vParamsObj := TJSONObject.Create;
        vParamsObj.AddPair('TrainedValues', TAIClassificationModelNaive(vBestModel).ToJSONObject);
        vJsonObj.AddPair('parameters', vParamsObj);
      end else begin
        raise Exception.Create('New model not defined in EasyAI.');
      end;
      vJSONString := vJsonObj.ToString;
      vBytes := TEncoding.UTF8.GetBytes(vJSONString);

      vFileStream := TFileStream.Create(aPathResultFile, fmCreate);
      try
        vFileStream.Write(vBytes[0], Length(vBytes));
      finally
        vFileStream.Free;
      end;
    finally
      vJsonObj.Free;
    end;
  finally
    vClassification.Free;
  end;
end;

procedure TEasyAIClassification.LoadDataset(aDataSet: TDataSet);
begin
  if aDataSet.RecordCount = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  UAuxGlobal.LoadDataset(aDataSet, FDataset, FNormalizationRange);     
  if (FModel is TKNNClassification) and Assigned(FModel) then begin    
    TKNNClassification(FModel).FDataset := Copy(FDataset);
    TKNNClassification(FModel).FNormalizationRange := FNormalizationRange;
  end;
end;

procedure TEasyAIClassification.LoadDataset(aDataSet : String; aHasHeader: Boolean);
begin
  UAuxGlobal.LoadDataset(aDataSet, FDataset, FNormalizationRange, aHasHeader);
  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;    
  if (FModel is TKNNClassification) and Assigned(FModel) then begin
    TKNNClassification(FModel).FDataset := Copy(FDataset);
    TKNNClassification(FModel).FNormalizationRange := FNormalizationRange;
  end;
end;

procedure TEasyAIClassification.LoadFromFile(aPath: String);
var
  vJsonObj, vParamsObj: TJSONObject;
  vKValue: Integer;
  vJSONString,
  vModel : String;
begin
  vJSONString := TFile.ReadAllText(aPath, TEncoding.UTF8);
  vJsonObj := TJSONObject.ParseJSONValue(vJSONString) as TJSONObject;
  try
    if Assigned(vJsonObj) then begin
      vModel := vJsonObj.GetValue('model').Value;
      if (vModel = 'KNN') then begin
        vParamsObj := vJsonObj.GetValue('parameters') as TJSONObject;
        vKValue := (vParamsObj.GetValue('K') as TJSONNumber).AsInt;
        FModel := TKNNClassification.Create(FDataset, FNormalizationRange, vKValue);
      end else if (vModel = 'DecisionTree') then begin
        vParamsObj := vJsonObj.GetValue('parameters') as TJSONObject;
        FModel := TDecisionTree.Create(0, scEntropy);
        TDecisionTree(FModel).LoadFromJson(TJSONObject(vParamsObj.GetValue('Structure')));
      end else if (vModel = 'GaussianNaive') then begin
        vParamsObj := vJsonObj.GetValue('parameters') as TJSONObject;
        FModel := TGaussianNaiveBayes.Create;
        TGaussianNaiveBayes(FModel).LoadFromJSONObject(vParamsObj.GetValue('TrainedValues') as TJSONObject);
      end else begin
        raise Exception.Create('Incorrect model on JSON.');
      end;
    end;
  finally
    vJsonObj.Free;
  end;
end;

function TEasyAIClassification.Predict(aSample: TAISampleAtr): String;
begin
  if FModel is TKNNClassification then begin
    if Length(FDataset) <= 1 then begin
      raise Exception.Create(ERROR_EMPTY_Dataset_EASY_PREDICT);
    end;
    Result := TKNNClassification(FModel).Predict(aSample);
  end else if FModel is TDecisionTree then begin
    Result := TDecisionTree(FModel).Predict(aSample);
  end else if FModel is TGaussianNaiveBayes then begin
    Result := TGaussianNaiveBayes(FModel).Predict(aSample);
  end;
end;

{ TEasyAIRegression }
destructor TEasyAIRegression.Destroy;
begin
  FModel.Free;
  inherited;
end;

procedure TEasyAIRegression.FindBestModel(aPathResultFile: String; aMode : TEasyTestingMode = tmStandard; aMaxThreads : Integer = 0; aCsvResultModels : String = ''; aLogFile : String = '');
var
  vNumSamples,
  i : Integer;
  vRegression : TAIRegressionSelector;
  vBestScore, vScore : Double;
  vModel, vBestModel : TAIRegressionTest;
  vJsonObj, vParamsObj: TJSONObject;
  vJSONString: string;
  vFileStream: TFileStream;
  vBytes: TBytes;
  vNormalizedScores : array of Double;
  vMinMAE, vMaxMAE, vMinMSE, vMaxMSE, vMinRMSE, vMaxRMSE, vMinR2, vMaxR2: Double;
begin
  vNumSamples := Length(FDataset);
  if Length(FDataset) <= 1 then begin
    raise Exception.Create(ERROR_EMPTY_Dataset_EASY_TRAIN);
  end;
  vRegression := TAIRegressionSelector.Create(FDataset, FNormalizationRange);
  try
    for i in CalculaKNNValores(vNumSamples, aMode) do begin
      vRegression.Models.AddKNN(i);
    end;
    vRegression.Models.AddLinearRegression;
    if (aMode = tmStandard) or (aMode = tmExtensive) then begin
      vRegression.Models.AddRidge(0.0001);
      vRegression.Models.AddRidge(0.001);
    end;
    if aMode = tmExtensive then begin
      vRegression.Models.AddRidge(0.0005);
      vRegression.Models.AddRidge(0.005);
      vRegression.Models.AddRidge(0.05);
      vRegression.Models.AddRidge(0.5);
      vRegression.Models.AddRidge(1.5);
      vRegression.Models.AddRidge(2);
    end;
    vRegression.Models.AddRidge(0.01);
    vRegression.Models.AddRidge(0.1);
    vRegression.Models.AddRidge(1);
    vRegression.Models.AddRidge(3);
    if aMode = tmExtensive then begin
      vRegression.Models.AddRidge(4);
      vRegression.Models.AddRidge(5);
      vRegression.Models.AddRidge(7);
      vRegression.Models.AddRidge(8);
      vRegression.Models.AddRidge(9);
    end;
    if (aMode = tmStandard) or (aMode = tmExtensive) then begin
      vRegression.Models.AddRidge(6);
      vRegression.Models.AddRidge(10);
    end;

    vRegression.RunTests(aCsvResultModels, aLogFile, aMaxThreads);

    vMinMAE := MaxDouble; vMaxMAE := -MaxDouble;
    vMinMSE := MaxDouble; vMaxMSE := -MaxDouble;
    vMinRMSE := MaxDouble; vMaxRMSE := -MaxDouble;
    vMinR2 := MaxDouble; vMaxR2 := -MaxDouble;

    for vModel in vRegression.Models.LstModels do begin
      if vModel.MAE < vMinMAE then vMinMAE := vModel.MAE;
      if vModel.MAE > vMaxMAE then vMaxMAE := vModel.MAE;

      if vModel.MSE < vMinMSE then vMinMSE := vModel.MSE;
      if vModel.MSE > vMaxMSE then vMaxMSE := vModel.MSE;

      if vModel.RMSE < vMinRMSE then vMinRMSE := vModel.RMSE;
      if vModel.RMSE > vMaxRMSE then vMaxRMSE := vModel.RMSE;

      if vModel.R2 < vMinR2 then vMinR2 := vModel.R2;
      if vModel.R2 > vMaxR2 then vMaxR2 := vModel.R2;
    end;


    vBestScore := -MaxDouble;
    SetLength(vNormalizedScores, vRegression.Models.LstModels.Count);
    vBestModel := nil;
    for I := 0 to vRegression.Models.LstModels.Count - 1 do begin
      vModel := vRegression.Models.LstModels[I];

      vNormalizedScores[I] := 0;
      if vMaxMAE - vMinMAE = 0 then begin
        vNormalizedScores[I] := vNormalizedScores[I] + 1;
      end else begin
        vNormalizedScores[I] := vNormalizedScores[I] + (1 - (vModel.MAE - vMinMAE) / (vMaxMAE - vMinMAE));
      end;

      if vMaxMSE - vMinMSE = 0 then begin
        vNormalizedScores[I] := vNormalizedScores[I] + 1;
      end else begin
        vNormalizedScores[I] := vNormalizedScores[I] + (1 - (vModel.MSE - vMinMSE) / (vMaxMSE - vMinMSE));
      end;

      if vMaxRMSE - vMinRMSE = 0 then begin
        vNormalizedScores[I] := vNormalizedScores[I] + 1;
      end else begin
        vNormalizedScores[I] := vNormalizedScores[I] + (1 - (vModel.RMSE - vMinRMSE) / (vMaxRMSE - vMinRMSE));
      end;

      if vMaxR2 - vMinR2 = 0 then begin
        vNormalizedScores[I] := vNormalizedScores[I] + 1;
      end else begin
        vNormalizedScores[I] := vNormalizedScores[I] + (1 - ((vModel.R2 - vMinR2) / (vMaxR2 - vMinR2)));
      end;

      vScore := vNormalizedScores[I] / 4;

      if vScore > vBestScore then begin
        vBestScore := vScore;
        vBestModel := vModel;
      end;
    end;

    vJsonObj := TJSONObject.Create;
    try
      vJsonObj.AddPair('Precision', TJSONNumber.Create(vBestScore));
      if vBestModel is TAIRegressionModelKNN then begin
        ShowMessageNeedDataset;
        vJsonObj.AddPair('model', 'KNN');
        vParamsObj := TJSONObject.Create;
        vParamsObj.AddPair('K', TJSONNumber.Create(TAIRegressionModelKNN(vBestModel).K));
        vJsonObj.AddPair('parameters', vParamsObj);
      end else if vBestModel is TAIRegressionModelLinear then begin
        ShowMessageNeedDataset(False);
        vJsonObj.AddPair('model', 'LinearRegression');
        vParamsObj := TJSONObject.Create;
        vParamsObj.AddPair('TrainedValues', TAIRegressionModelLinear(vBestModel).ToJSONObject);
        vJsonObj.AddPair('parameters', vParamsObj);
      end else if vBestModel is TAIRegressionModelRidge then begin
        ShowMessageNeedDataset(False);
        vJsonObj.AddPair('model', 'Ridge');
        vParamsObj := TJSONObject.Create;
        vParamsObj.AddPair('TrainedValues', TAIRegressionModelRidge(vBestModel).ToJSONObject);
        vJsonObj.AddPair('parameters', vParamsObj);
      end else begin
        raise Exception.Create('New model not defined in EasyAI.');
      end;
      vJSONString := vJsonObj.ToString;
      vBytes := TEncoding.UTF8.GetBytes(vJSONString);

      vFileStream := TFileStream.Create(aPathResultFile, fmCreate);
      try
        vFileStream.Write(vBytes[0], Length(vBytes));
      finally
        vFileStream.Free;
      end;
    finally
      vJsonObj.Free;
    end;
  finally
    vRegression.Free;
  end;
end;

procedure TEasyAIRegression.LoadDataset(aDataSet: TDataSet);
begin
  if aDataSet.RecordCount = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  UAuxGlobal.LoadDataset(aDataSet, FDataset, FNormalizationRange);
  if (FModel is TKNNRegression) and Assigned(FModel) then begin
    TKNNRegression(FModel).FDataset := Copy(FDataset);
    TKNNRegression(FModel).FNormalizationRange := FNormalizationRange;
  end;
end;

procedure TEasyAIRegression.LoadDataset(aDataSet: String; aHasHeader: Boolean);
begin
  UAuxGlobal.LoadDataset(aDataSet, FDataset, FNormalizationRange, aHasHeader);
  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;  
  if (FModel is TKNNRegression) and Assigned(FModel) then begin
    TKNNRegression(FModel).FDataset := Copy(FDataset);
    TKNNRegression(FModel).FNormalizationRange := FNormalizationRange;
  end;
end;

procedure TEasyAIRegression.LoadFromFile(aPath: String);
var
  vJsonObj, vParamsObj: TJSONObject;
  vKValue: Integer;
  vJSONString,
  vModel : String;
begin
  vJSONString := TFile.ReadAllText(aPath, TEncoding.UTF8);
  vJsonObj := TJSONObject.ParseJSONValue(vJSONString) as TJSONObject;
  try
    if Assigned(vJsonObj) then begin
      vModel := vJsonObj.GetValue('model').Value;
      if (vModel = 'KNN') then begin
        vParamsObj := vJsonObj.GetValue('parameters') as TJSONObject;
        vKValue := (vParamsObj.GetValue('K') as TJSONNumber).AsInt;
        FModel := TKNNRegression.Create(FDataset, FNormalizationRange, vKValue);
      end else if (vModel = 'LinearRegression') then begin
        vParamsObj := vJsonObj.GetValue('parameters') as TJSONObject;
        FModel := TLinearRegression.Create;
        TLinearRegression(FModel).FromJson(vParamsObj.GetValue('TrainedValues') as TJSONObject);
      end else if (vModel = 'Ridge') then begin
        vParamsObj := vJsonObj.GetValue('parameters') as TJSONObject;
        FModel := TRidgeRegression.Create;
        TRidgeRegression(FModel).FromJson(vParamsObj.GetValue('TrainedValues') as TJSONObject);
      end else begin
        raise Exception.Create('Incorrect model on JSON.');
      end;
    end;
  finally
    vJsonObj.Free;
  end;
end;

function TEasyAIRegression.Predict(aSample: TAISampleAtr): Double;
var
  vTempArray : TAISamplesAtr;
begin
  vTempArray := [aSample];
  if FModel is TKNNRegression then begin
    if Length(FDataset) <= 1 then begin
      raise Exception.Create(ERROR_EMPTY_Dataset_EASY_PREDICT);
    end;
    Result := TKNNRegression(FModel).Predict(vTempArray[0]);
  end else if FModel is TLinearRegression then begin
    Result := TLinearRegression(FModel).Predict(vTempArray[0]);
  end else if FModel is TRidgeRegression then begin
    Result := TRidgeRegression(FModel).Predict(vTempArray[0]);
  end else begin
    Result := 0;
  end;
end;

{ TEasyAIRecommendationFromItem }

constructor TEasyAIRecommendationFromItem.Create(aItemsToRecommendCount: Integer);
begin
  FItemsToRecommendCount := aItemsToRecommendCount;
end;

procedure FindBestModelRec(aDataset : TAIDatasetRecommendation; aNormalizationRange : TNormalizationRange; aItemsToRecommendCount : Integer; aPathResultFile: String;  aMode : TEasyTestingMode; aItem : Boolean; aMaxThreads : Integer = 0; aCsvResultModels : String = ''; aLogFile : String = '');
var
  vBestIndex,
  vNumSamples,
  i, vK : Integer;
  vRecommendation : TAIRecommendationSelector;
  vMoreAccuracy : Double;
  vBestModel : TAIRecommendationModel;
  vJsonObj, vParamsObj: TJSONObject;
  vJSONString: string;
  vFileStream: TFileStream;
  vBytes: TBytes;

  procedure _AddModel(aK: Integer;
                      aAggregMethod: TUserScoreAggregationMethod; aDistanceMethod: TDistanceMode; aItem : Boolean = False);
  begin
    if aItem then begin
      vRecommendation.Models.AddItemItem(aItemsToRecommendCount, aDistanceMethod);
    end else begin
      vRecommendation.Models.AddUserUser(aItemsToRecommendCount, aK, aAggregMethod, aDistanceMethod);
    end;

  end;

begin
  if Length(aDataset) <= 1 then begin
    raise Exception.Create(ERROR_EMPTY_Dataset_EASY_TRAIN);
  end;
  vNumSamples := Length(aDataset);
  if vNumSamples = 0 then begin
    raise Exception.Create('No Dataset loaded.');
  end;
  vRecommendation := TAIRecommendationSelector.Create(aDataset, aNormalizationRange);

  try
    if (aMode = tmFast) then begin
      if aItem then begin
        _AddModel(0, TUserScoreAggregationMethod.amMode, TDistanceMode.dmManhattan, aItem);
        _AddModel(0, TUserScoreAggregationMethod.amMode, TDistanceMode.dmCosine, aItem);
        _AddModel(0, TUserScoreAggregationMethod.amMode, TDistanceMode.dmJaccard, aItem);
      end else begin
        vK := Round(Sqrt(Length(aDataset)) / 10);
        if vK < 3 then begin
          vK := 3;
        end;
        _AddModel(vK, TUserScoreAggregationMethod.amMode,            TDistanceMode.dmCosine, aItem);
        _AddModel(vK, TUserScoreAggregationMethod.amWeightedAverage, TDistanceMode.dmCosine, aItem);
        _AddModel(vK, TUserScoreAggregationMethod.amSimpleSum,       TDistanceMode.dmCosine, aItem);
      end;
    end else if (aMode = tmStandard) then begin
      if aItem then begin
        _AddModel(0, TUserScoreAggregationMethod.amMode, TDistanceMode.dmManhattan, aItem);
        _AddModel(0, TUserScoreAggregationMethod.amMode, TDistanceMode.dmCosine, aItem);
        _AddModel(0, TUserScoreAggregationMethod.amMode, TDistanceMode.dmJaccard, aItem);
        _AddModel(0, TUserScoreAggregationMethod.amMode, TDistanceMode.dmPearson, aItem);
      end else begin
        for vK in CalculaKNNValores(Length(aDataset), tmFast) do begin
          _AddModel(vK, TUserScoreAggregationMethod.amMode,           TDistanceMode.dmCosine, aItem);
          _AddModel(vK, TUserScoreAggregationMethod.amWeightedAverage, TDistanceMode.dmCosine, aItem);
          _AddModel(vK, TUserScoreAggregationMethod.amSimpleSum,    TDistanceMode.dmCosine, aItem);
        end;
      end;
    end else begin
      if aItem then begin
        _AddModel(0, TUserScoreAggregationMethod.amMode, TDistanceMode.dmManhattan, aItem);
        _AddModel(0, TUserScoreAggregationMethod.amMode, TDistanceMode.dmEuclidean, aItem);
        _AddModel(0, TUserScoreAggregationMethod.amMode, TDistanceMode.dmCosine, aItem);
        _AddModel(0, TUserScoreAggregationMethod.amMode, TDistanceMode.dmJaccard, aItem);
        _AddModel(0, TUserScoreAggregationMethod.amMode, TDistanceMode.dmPearson, aItem);
      end else begin
        for vK in CalculaKNNValores(Length(aDataset), tmFast) do begin
          _AddModel(vK, TUserScoreAggregationMethod.amMode, TDistanceMode.dmManhattan, aItem);
          _AddModel(vK, TUserScoreAggregationMethod.amMode, TDistanceMode.dmEuclidean, aItem);
          _AddModel(vK, TUserScoreAggregationMethod.amMode, TDistanceMode.dmCosine, aItem);
          _AddModel(vK, TUserScoreAggregationMethod.amMode, TDistanceMode.dmJaccard, aItem);
          _AddModel(vK, TUserScoreAggregationMethod.amMode, TDistanceMode.dmPearson, aItem);

          _AddModel(vK, TUserScoreAggregationMethod.amWeightedAverage, TDistanceMode.dmManhattan, aItem);
          _AddModel(vK, TUserScoreAggregationMethod.amSimpleSum,    TDistanceMode.dmManhattan, aItem);

          _AddModel(vK, TUserScoreAggregationMethod.amWeightedAverage, TDistanceMode.dmEuclidean, aItem);
          _AddModel(vK, TUserScoreAggregationMethod.amSimpleSum,    TDistanceMode.dmEuclidean, aItem);

          _AddModel(vK, TUserScoreAggregationMethod.amWeightedAverage, TDistanceMode.dmCosine, aItem);
          _AddModel(vK, TUserScoreAggregationMethod.amSimpleSum,    TDistanceMode.dmCosine, aItem);

          _AddModel(vK, TUserScoreAggregationMethod.amWeightedAverage, TDistanceMode.dmJaccard, aItem);
          _AddModel(vK, TUserScoreAggregationMethod.amSimpleSum,    TDistanceMode.dmJaccard, aItem);

          _AddModel(vK, TUserScoreAggregationMethod.amWeightedAverage, TDistanceMode.dmPearson, aItem);
          _AddModel(vK, TUserScoreAggregationMethod.amSimpleSum,    TDistanceMode.dmPearson, aItem);
        end;
      end;
    end;

    if aItem then begin
      vRecommendation.RunTestsItemItem(aCsvResultModels, aLogFile, aMaxThreads);
    end else begin
      vRecommendation.RunTestsUserUser(aCsvResultModels, aLogFile, aMaxThreads);
    end;

    vMoreAccuracy := 0;
    vBestIndex := 0;
    for i := 0 to vRecommendation.Models.LstModels.Count-1 do begin
      if vRecommendation.Models.LstModels[i].Accuracy > vMoreAccuracy then begin
        vBestIndex := i;
        vMoreAccuracy := vRecommendation.Models.LstModels[i].Accuracy;
      end;
    end;

    vJsonObj := TJSONObject.Create;
    try
      vBestModel := vRecommendation.Models.LstModels[vBestIndex];
      ShowMessageNeedDataset;
      vJsonObj.AddPair('Precision', TJSONNumber.Create(vBestModel.Accuracy));
      if aItem then begin
        vJsonObj.AddPair('From', 'Item');
      end else begin
        vJsonObj.AddPair('From', 'User');
      end;
      vParamsObj := TJSONObject.Create;
      vParamsObj.AddPair('ItemsToRecommendCount', TJSONNumber.Create(vBestModel.Model.ItemsToRecommendCount));
      vParamsObj.AddPair('K', TJSONNumber.Create(vBestModel.Model.K));
      if not aItem then begin
        vParamsObj.AddPair('AggregMethod', TJSONNumber.Create(Ord(vBestModel.Model.AggregMethod)));
      end;
      vParamsObj.AddPair('DistanceMethod', TJSONNumber.Create(Ord(vBestModel.Model.DistanceMethod)));

      vJsonObj.AddPair('parameters', vParamsObj);
      vJSONString := vJsonObj.ToString;
      vBytes := TEncoding.UTF8.GetBytes(vJSONString);

      vFileStream := TFileStream.Create(aPathResultFile, fmCreate);
      try
        vFileStream.Write(vBytes[0], Length(vBytes));
      finally
        vFileStream.Free;
      end;
    finally
      vJsonObj.Free;
    end;
  finally
    vRecommendation.Free;
  end;
end;

destructor TEasyAIRecommendationFromItem.Destroy;
begin
  FModel.Free;
  inherited;
end;

procedure TEasyAIRecommendationFromItem.FindBestModel(aPathResultFile: String; aMode : TEasyTestingMode = tmStandard; aMaxThreads : Integer = 0; aCsvResultModels : String = ''; aLogFile : String = '');
begin
  FindBestModelRec(FDataset, FNormalizationRange, FItemsToRecommendCount, aPathResultFile, aMode, True, aMaxThreads, aCsvResultModels, aLogFile);
end;

procedure TEasyAIRecommendationFromItem.LoadDataset(aDataSet: String; aHasHeader: Boolean);
begin
  UAuxGlobal.LoadDataset(aDataSet, FDataset, FNormalizationRange, aHasHeader);
  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  if Assigned(FModel) then begin
    FModel.FDataset := Copy(FDataset);
    FModel.FNormalizationRange := FNormalizationRange;
    FModel.GenerateItemMatrix;
  end;
end;

procedure TEasyAIRecommendationFromItem.LoadDataset(aDataSet: TDataSet);
begin
  if aDataSet.RecordCount = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  UAuxGlobal.LoadDataset(aDataSet, FDataset, FNormalizationRange);
  if Assigned(FModel) then begin
    FModel.FDataset := Copy(FDataset);
    FModel.FNormalizationRange := FNormalizationRange;
    FModel.GenerateItemMatrix;
  end;
end;

procedure TEasyAIRecommendationFromItem.LoadFromFile(aPath: String);
var
  vJsonObj, vParamsObj: TJSONObject;
  vJSONString,
  vModel : String;
begin
  vJSONString := TFile.ReadAllText(aPath, TEncoding.UTF8);
  vJsonObj := TJSONObject.ParseJSONValue(vJSONString) as TJSONObject;
  try
    if Assigned(vJsonObj) then begin
      vModel := vJsonObj.GetValue('From').Value;
      vParamsObj := vJsonObj.GetValue('parameters') as TJSONObject;
      FModel := TRecommender.Create(FDataset, FNormalizationRange, StrToInt(vParamsObj.GetValue('ItemsToRecommendCount').Value),
                                    StrToInt(vParamsObj.GetValue('K').Value),
                                    TUserScoreAggregationMethod.amMode,
                                    TDistanceMode(StrToInt(vParamsObj.GetValue('DistanceMethod').Value)), False);
    end;
  finally
    vJsonObj.Free;
  end;
end;

function TEasyAIRecommendationFromItem.RecommendItem(aFromItemSample: TAISampleAtr) : TArray<Integer>;
begin
  if Length(FDataset) <= 1 then begin
    raise Exception.Create(ERROR_EMPTY_Dataset_EASY_PREDICT);
  end;
  Result := FModel.RecommendFromItem(aFromItemSample);
end;

function TEasyAIRecommendationFromItem.RecommendItem(aFromItemID: Integer) : TArray<Integer>;
begin
  if Length(FDataset) <= 1 then begin
    raise Exception.Create(ERROR_EMPTY_Dataset_EASY_PREDICT);
  end;
  Result := FModel.RecommendFromItem(aFromItemID);
end;

{ TEasyAIRecommendationFromUser }

constructor TEasyAIRecommendationFromUser.Create(aItemsToRecommendCount: Integer);
begin
  FItemsToRecommendCount := aItemsToRecommendCount;
end;

destructor TEasyAIRecommendationFromUser.Destroy;
begin
  FModel.Free;
  inherited;
end;

procedure TEasyAIRecommendationFromUser.FindBestModel(aPathResultFile: String; aMode : TEasyTestingMode = tmStandard; aMaxThreads : Integer = 0; aCsvResultModels : String = ''; aLogFile : String = '');
begin
  FindBestModelRec(FDataset, FNormalizationRange, FItemsToRecommendCount, aPathResultFile, aMode, False, aMaxThreads, aCsvResultModels, aLogFile);
end;

procedure TEasyAIRecommendationFromUser.LoadDataset(aDataSet: String; aHasHeader: Boolean);
begin
  UAuxGlobal.LoadDataset(aDataSet, FDataset, FNormalizationRange, aHasHeader);

  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;                                          
  if Assigned(FModel) then begin    
    FModel.FDataset := Copy(FDataset);
    FModel.FNormalizationRange := FNormalizationRange;
  end;
end;

procedure TEasyAIRecommendationFromUser.LoadDataset(aDataSet: TDataSet);
begin
  if aDataSet.RecordCount = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  UAuxGlobal.LoadDataset(aDataSet, FDataset, FNormalizationRange);        
  if Assigned(FModel) then begin    
    FModel.FDataset := Copy(FDataset);
    FModel.FNormalizationRange := FNormalizationRange;
  end;
end;

procedure TEasyAIRecommendationFromUser.LoadFromFile(aPath: String);
var
  vJsonObj, vParamsObj: TJSONObject;
  vJSONString,
  vModel : String;
begin
  vJSONString := TFile.ReadAllText(aPath, TEncoding.UTF8);
  vJsonObj := TJSONObject.ParseJSONValue(vJSONString) as TJSONObject;
  try
    if Assigned(vJsonObj) then begin
      vModel := vJsonObj.GetValue('From').Value;
      vParamsObj := vJsonObj.GetValue('parameters') as TJSONObject;
      FModel := TRecommender.Create(FDataset, FNormalizationRange, StrToInt(vParamsObj.GetValue('ItemsToRecommendCount').Value),
                                    StrToInt(vParamsObj.GetValue('K').Value),
                                    TUserScoreAggregationMethod(StrToInt(vParamsObj.GetValue('AggregMethod').Value)),
                                    TDistanceMode(StrToInt(vParamsObj.GetValue('DistanceMethod').Value)), False);
    end;
  finally
    vJsonObj.Free;
  end;

end;

function TEasyAIRecommendationFromUser.RecommendItem(aFromUserSample: TAISampleAtr): TArray<Integer>;
begin
  if Length(FDataset) <= 1 then begin
    raise Exception.Create(ERROR_EMPTY_Dataset_EASY_PREDICT);
  end;
  Result := FModel.RecommendFromUser(aFromUserSample);
end;

function TEasyAIRecommendationFromUser.RecommendItem(aFromUserID : Integer): TArray<Integer>;
begin
  if Length(FDataset) <= 1 then begin
    raise Exception.Create(ERROR_EMPTY_Dataset_EASY_PREDICT);
  end;
  Result := FModel.RecommendFromUser(aFromUserID);
end;

end.
