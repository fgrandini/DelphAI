unit UNaiveBayes;

interface

uses
  System.SysUtils, System.Generics.Collections, UAITypes, UAIModel,
  System.JSON, Data.DB;

type

  TGaussianNaiveBayes = class(TClassificationModel)
  private
    FClasses: TDictionary<string, Integer>;
    FClassProbabilities: TDictionary<string, Double>;
    FMeans: TDictionary<string, TAISampleAtr>;
    FVariances: TDictionary<string, TAISampleAtr>;
    procedure CalculateClassStatistics(const Dataset: TAIDatasetClassification);
    function GaussianProbability(x, mean, variance: Double): Double;
    procedure DoTrain;
  public
    procedure Train(aTrainingData : TAIDatasetClassification; aNormalizationRange : TNormalizationRange); overload;
    procedure Train(aTrainingData : String; aHasHeader : Boolean = True); overload;
    procedure Train(aTrainingData : TDataSet); overload;
    function Predict(aSample : TAISampleAtr; aInputNormalized : Boolean = False): string;
    function ToJSONObject: TJSONObject;
    procedure SaveToFile(const aFileName: string);
    procedure LoadFromFile(const aFileName: string);
    procedure LoadFromJSONObject(aJsonObj: TJSONObject);
    constructor Create; overload;
    constructor Create(aTrainedFile : String); overload;
    destructor Destroy; override;

  end;

implementation

uses
  System.Math, System.Classes, UAuxGlobal;

{ TGaussianNaiveBayes }

procedure TGaussianNaiveBayes.CalculateClassStatistics(const Dataset: TAIDatasetClassification);
var
  vClassCount: TDictionary<string, Integer>;
  vSum, vSumSquare: TDictionary<string, TAISampleAtr>;
  vSample: TAISampleClassification;
  i : Integer;
  vTempArray: TAISampleAtr;
  vCount: Integer;
  vMean, vVariance: TAISampleAtr;
begin
  vClassCount := TDictionary<string, Integer>.Create;
  vSum := TDictionary<string, TAISampleAtr>.Create;
  vSumSquare := TDictionary<string, TAISampleAtr>.Create;

  try
    for vSample in Dataset do
    begin
      if not vClassCount.ContainsKey(vSample.Value) then
      begin
        vClassCount.Add(vSample.Value, 0);
        vSum.Add(vSample.Value, TArray<Double>.Create());
        vSumSquare.Add(vSample.Value, TArray<Double>.Create());
      end;
    end;

    for vSample in Dataset do
    begin
      vClassCount[vSample.Value] := vClassCount[vSample.Value] + 1;

      vTempArray := vSum[vSample.Value];
      for i := 0 to Length(vSample.Key) - 1 do
      begin
        if i >= Length(vTempArray) then
        begin
          SetLength(vTempArray, i + 1);
        end;
        vTempArray[i] := vTempArray[i] + vSample.Key[i];
      end;
      vSum[vSample.Value] := vTempArray;

      vTempArray := vSumSquare[vSample.Value];
      for i := 0 to Length(vSample.Key) - 1 do
      begin
        if i >= Length(vTempArray) then
        begin
          SetLength(vTempArray, i + 1);
        end;
        vTempArray[i] := vTempArray[i] + Sqr(vSample.Key[i]);
      end;
      vSumSquare[vSample.Value] := vTempArray;
    end;

    for vSample in Dataset do
    begin
      vCount := vClassCount[vSample.Value];
      vMean := TArray<Double>.Create();
      vVariance := TArray<Double>.Create();

      for i := 0 to Length(vSum[vSample.Value]) - 1 do
      begin
        SetLength(vMean, i + 1);
        SetLength(vVariance, i + 1);

        vMean[i] := vSum[vSample.Value][i] / vCount;
        vVariance[i] := (vSumSquare[vSample.Value][i] / vCount) - Sqr(vMean[i]);
      end;

      FMeans.AddOrSetValue(vSample.Value, vMean);
      FVariances.AddOrSetValue(vSample.Value, vVariance);
    end;

  finally
    vClassCount.Free;
    vSum.Free;
    vSumSquare.Free;
  end;
end;

constructor TGaussianNaiveBayes.Create(aTrainedFile: String);
begin
  FClasses := TDictionary<string, Integer>.Create;
  FClassProbabilities := TDictionary<string, Double>.Create;
  FMeans := TDictionary<string, TAISampleAtr>.Create;
  FVariances := TDictionary<string, TAISampleAtr>.Create;
  LoadFromFile(aTrainedFile);
end;

constructor TGaussianNaiveBayes.Create;
begin
  FClasses := TDictionary<string, Integer>.Create;
  FClassProbabilities := TDictionary<string, Double>.Create;
  FMeans := TDictionary<string, TAISampleAtr>.Create;
  FVariances := TDictionary<string, TAISampleAtr>.Create;
end;

function TGaussianNaiveBayes.GaussianProbability(x, mean, variance: Double): Double;
begin
  if variance = 0 then
    Result := 0
  else
    Result := (1 / Sqrt(2 * Pi * variance)) * Exp(-Sqr(x - mean) / (2 * variance));
end;

function TGaussianNaiveBayes.Predict(aSample : TAISampleAtr; aInputNormalized : Boolean = False): string;
var
  vClassLabel: string;
  vProbability, vMaxProbability: Double;
  vMean, vVariance: TAISampleAtr;
  i: Integer;
  vBestClass: string;
begin
  aSample := Copy(aSample);
  if not aInputNormalized then begin
    ValidateAndNormalizeInput(aSample);
  end;
  vMaxProbability := -Infinity;

  for vClassLabel in FClasses.Keys do
  begin
    vProbability := FClassProbabilities[vClassLabel];
    vMean := FMeans[vClassLabel];
    vVariance := FVariances[vClassLabel];

    for i := 0 to Length(aSample) - 1 do
      vProbability := vProbability * GaussianProbability(aSample[i], vMean[i], vVariance[i]);

    if vProbability > vMaxProbability then
    begin
      vMaxProbability := vProbability;
      vBestClass := vClassLabel;
    end;
  end;

  Result := vBestClass;
end;

function TGaussianNaiveBayes.ToJSONObject: TJSONObject;
var
  vRoot,
  vJsonObj, vMeanObj, vVarianceObj: TJSONObject;
  vClassLabel: string;
  vMeanArray, vVarianceArray: TJSONArray;
  i: Integer;
begin
  vRoot := TJSONObject.Create;
  vJsonObj := TJSONObject.Create;

  vRoot.AddPair('NormalizationRange', NormRangeToJSON);
  vRoot.AddPair('InputLength', TJSONNumber.Create(InputLength));
  vRoot.AddPair('Model', vJsonObj);

  for vClassLabel in FClassProbabilities.Keys do
  begin
    vJsonObj.AddPair(vClassLabel + '_probability', TJSONNumber.Create(FClassProbabilities[vClassLabel]));
    vJsonObj.AddPair(vClassLabel + '_count', TJSONNumber.Create(FClasses[vClassLabel]));
  end;

  for vClassLabel in FMeans.Keys do
  begin
    vMeanArray := TJSONArray.Create;
    vVarianceArray := TJSONArray.Create;

    for i := 0 to Length(FMeans[vClassLabel]) - 1 do
    begin
      vMeanArray.Add(FMeans[vClassLabel][i]);
      vVarianceArray.Add(FVariances[vClassLabel][i]);
    end;

    vMeanObj := TJSONObject.Create;
    vMeanObj.AddPair('mean', vMeanArray);
    vJsonObj.AddPair(vClassLabel + '_mean', vMeanObj);

    vVarianceObj := TJSONObject.Create;
    vVarianceObj.AddPair('variance', vVarianceArray);
    vJsonObj.AddPair(vClassLabel + '_variance', vVarianceObj);
  end;

  Result := vRoot;
end;

destructor TGaussianNaiveBayes.Destroy;
begin
  FClasses.Clear;
  FClasses.Free;
  FClassProbabilities.Free;
  FMeans.Clear;
  FMeans.Free;
  FVariances.Clear;
  FVariances.Free;
  inherited;
end;

procedure TGaussianNaiveBayes.DoTrain;
var
  vTotalSamples : Integer;
  vSample : TAISampleClassification;
begin
  PopulateInputLenght;

  vTotalSamples := Length(FDataset);
  for vSample in FDataset do begin
    if not FClasses.ContainsKey(vSample.Value) then begin
      FClasses.Add(vSample.Value, 0);
    end;
    FClasses[vSample.Value] := FClasses[vSample.Value] + 1;
  end;

  for vSample in FDataset do begin
    FClassProbabilities.AddOrSetValue(vSample.Value, FClasses[vSample.Value] / vTotalSamples);
  end;

  CalculateClassStatistics(FDataset);
  Trained := True;
end;

procedure TGaussianNaiveBayes.Train(aTrainingData: TAIDatasetClassification;
  aNormalizationRange: TNormalizationRange);
begin
  FNormalizationRange := aNormalizationRange;
  FDataset := Copy(aTrainingData);
  DoTrain;
end;

procedure TGaussianNaiveBayes.Train(aTrainingData: String; aHasHeader: Boolean);
begin
  LoadDataset(aTrainingData, FDataset, FNormalizationRange, aHasHeader);
  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  DoTrain;
end;

procedure TGaussianNaiveBayes.Train(aTrainingData: TDataSet);
begin
  if aTrainingData.RecordCount = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  LoadDataset(aTrainingData, FDataset, FNormalizationRange);
  DoTrain;
end;

procedure TGaussianNaiveBayes.SaveToFile(const aFileName: string);
var
  vJsonObj: TJSONObject;
  vJsonString: TStringList;
begin
  vJsonObj := ToJSONObject;
  try
    vJsonString := TStringList.Create;
    try
      vJsonString.Text := vJsonObj.ToString;
      vJsonString.SaveToFile(aFileName);
    finally
      vJsonString.Free;
    end;
  finally
    vJsonObj.Free;
  end;
end;

procedure TGaussianNaiveBayes.LoadFromFile(const aFileName: string);
var
  vJsonString: TStringList;
  vJsonObj: TJSONObject;
begin
  vJsonString := TStringList.Create;
  try
    vJsonString.LoadFromFile(aFileName);
    vJsonObj := TJSONObject.ParseJSONValue(vJsonString.Text) as TJSONObject;
    try
      if vJsonObj <> nil then begin
        LoadFromJSONObject(vJsonObj);
      end;
    finally
      vJsonObj.Free;
    end;
  finally
    vJsonString.Free;
  end;
end;

procedure TGaussianNaiveBayes.LoadFromJSONObject(aJsonObj: TJSONObject);
var
  vMeanObj, vVarianceObj: TJSONObject;
  vMeanArray, vVarianceArray: TJSONArray;
  vClassLabel: string;
  i: Integer;
  vTempArray: TAISampleAtr;
  vJsonPair: TJSONPair;
begin
  InputLength := StrToInt(aJsonObj.FindValue('InputLength').Value);
  JSONToNormRange(aJsonObj.FindValue('NormalizationRange') as TJSONObject);
  aJsonObj := aJsonObj.FindValue('Model') as TJSONObject;

  FClasses := TDictionary<string, Integer>.Create;
  FClassProbabilities := TDictionary<string, Double>.Create;
  FMeans := TDictionary<string, TAISampleAtr>.Create;
  FVariances := TDictionary<string, TAISampleAtr>.Create;

  for vJsonPair in aJsonObj do begin
    vClassLabel := vJsonPair.JsonString.Value;

    if vClassLabel.EndsWith('_count') then begin
      FClasses.AddOrSetValue(vClassLabel.Replace('_count', ''), vJsonPair.JsonValue.AsType<Integer>);
    end
    else if vClassLabel.EndsWith('_probability') then begin
      FClassProbabilities.AddOrSetValue(vClassLabel.Replace('_probability', ''), vJsonPair.JsonValue.AsType<Double>);
    end;
  end;

  for vClassLabel in FClasses.Keys do begin
    vMeanObj := aJsonObj.GetValue(vClassLabel + '_mean') as TJSONObject;
    vVarianceObj := aJsonObj.GetValue(vClassLabel + '_variance') as TJSONObject;

    vMeanArray := vMeanObj.GetValue('mean') as TJSONArray;
    vVarianceArray := vVarianceObj.GetValue('variance') as TJSONArray;


    SetLength(vTempArray, vMeanArray.Count);
    for i := 0 to vMeanArray.Count - 1 do
    begin
      vTempArray[i] := vMeanArray.Items[i].AsType<Double>;
    end;
    FMeans.AddOrSetValue(vClassLabel, vTempArray);

    SetLength(vTempArray, vVarianceArray.Count);
    for i := 0 to vVarianceArray.Count - 1 do
    begin
      vTempArray[i] := vVarianceArray.Items[i].AsType<Double>;
    end;
    FVariances.AddOrSetValue(vClassLabel, vTempArray);
  end;

  Trained := True;
end;

end.

