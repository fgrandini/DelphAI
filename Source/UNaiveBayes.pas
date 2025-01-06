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
    procedure Train(aTrainingData : String; aHaveHeader : Boolean = True); overload;
    procedure Train(aTrainingData : TDataSet); overload;
    function Predict(aSample : TAISampleAtr; aInputNormalized : Boolean = False): string;
    function ToJSONObject: TJSONObject;
    procedure SaveToFile(const FileName: string);
    procedure LoadFromFile(const FileName: string);
    procedure LoadFromJSONObject(JsonObj: TJSONObject);
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
  ClassCount: TDictionary<string, Integer>;
  Sum, SumSquare: TDictionary<string, TAISampleAtr>;
  Sample: TAISampleClassification;
  i : Integer;
  TempArray: TAISampleAtr;
  Count: Integer;
  Mean, Variance: TAISampleAtr;
begin
  ClassCount := TDictionary<string, Integer>.Create;
  Sum := TDictionary<string, TAISampleAtr>.Create;
  SumSquare := TDictionary<string, TAISampleAtr>.Create;

  try
    for Sample in Dataset do
    begin
      if not ClassCount.ContainsKey(Sample.Value) then
      begin
        ClassCount.Add(Sample.Value, 0);
        Sum.Add(Sample.Value, TArray<Double>.Create());
        SumSquare.Add(Sample.Value, TArray<Double>.Create());
      end;
    end;

    for Sample in Dataset do
    begin
      ClassCount[Sample.Value] := ClassCount[Sample.Value] + 1;

      TempArray := Sum[Sample.Value];
      for i := 0 to Length(Sample.Key) - 1 do
      begin
        if i >= Length(TempArray) then
        begin
          SetLength(TempArray, i + 1);
        end;
        TempArray[i] := TempArray[i] + Sample.Key[i];
      end;
      Sum[Sample.Value] := TempArray;

      TempArray := SumSquare[Sample.Value];
      for i := 0 to Length(Sample.Key) - 1 do
      begin
        if i >= Length(TempArray) then
        begin
          SetLength(TempArray, i + 1);
        end;
        TempArray[i] := TempArray[i] + Sqr(Sample.Key[i]);
      end;
      SumSquare[Sample.Value] := TempArray;
    end;

    for Sample in Dataset do
    begin
      Count := ClassCount[Sample.Value];
      Mean := TArray<Double>.Create();
      Variance := TArray<Double>.Create();

      for i := 0 to Length(Sum[Sample.Value]) - 1 do
      begin
        SetLength(Mean, i + 1);
        SetLength(Variance, i + 1);

        Mean[i] := Sum[Sample.Value][i] / Count;
        Variance[i] := (SumSquare[Sample.Value][i] / Count) - Sqr(Mean[i]);
      end;

      FMeans.AddOrSetValue(Sample.Value, Mean);
      FVariances.AddOrSetValue(Sample.Value, Variance);
    end;

  finally
    ClassCount.Free;
    Sum.Free;
    SumSquare.Free;
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
  ClassLabel: string;
  Probability, MaxProbability: Double;
  Mean, Variance: TAISampleAtr;
  i: Integer;
  BestClass: string;
begin
  aSample := Copy(aSample);
  if not aInputNormalized then begin
    ValidateAndNormalizeInput(aSample);
  end;
  MaxProbability := -Infinity;

  for ClassLabel in FClasses.Keys do
  begin
    Probability := FClassProbabilities[ClassLabel];
    Mean := FMeans[ClassLabel];
    Variance := FVariances[ClassLabel];

    for i := 0 to Length(aSample) - 1 do
      Probability := Probability * GaussianProbability(aSample[i], Mean[i], Variance[i]);

    if Probability > MaxProbability then
    begin
      MaxProbability := Probability;
      BestClass := ClassLabel;
    end;
  end;

  Result := BestClass;
end;

function TGaussianNaiveBayes.ToJSONObject: TJSONObject;
var
  vRoot,
  JsonObj, MeanObj, VarianceObj: TJSONObject;
  ClassLabel: string;
  MeanArray, VarianceArray: TJSONArray;
  i: Integer;
begin
  vRoot := TJSONObject.Create;
  JsonObj := TJSONObject.Create;

  vRoot.AddPair('NormalizationRange', NormRangeToJSON);
  vRoot.AddPair('InputLength', InputLength);
  vRoot.AddPair('Model', JsonObj);

  for ClassLabel in FClassProbabilities.Keys do
  begin
    JsonObj.AddPair(ClassLabel + '_probability', TJSONNumber.Create(FClassProbabilities[ClassLabel]));
    JsonObj.AddPair(ClassLabel + '_count', TJSONNumber.Create(FClasses[ClassLabel])); 
  end;

  for ClassLabel in FMeans.Keys do
  begin
    MeanArray := TJSONArray.Create;
    VarianceArray := TJSONArray.Create;

    for i := 0 to Length(FMeans[ClassLabel]) - 1 do
    begin
      MeanArray.Add(FMeans[ClassLabel][i]);
      VarianceArray.Add(FVariances[ClassLabel][i]);
    end;

    MeanObj := TJSONObject.Create;
    MeanObj.AddPair('mean', MeanArray);
    JsonObj.AddPair(ClassLabel + '_mean', MeanObj);

    VarianceObj := TJSONObject.Create;
    VarianceObj.AddPair('variance', VarianceArray);
    JsonObj.AddPair(ClassLabel + '_variance', VarianceObj);
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

procedure TGaussianNaiveBayes.Train(aTrainingData: String; aHaveHeader: Boolean);
begin
  LoadDataset(aTrainingData, FDataset, FNormalizationRange, aHaveHeader);
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

procedure TGaussianNaiveBayes.SaveToFile(const FileName: string);
var
  JsonObj: TJSONObject;
  JsonString: TStringList;
begin
  JsonObj := ToJSONObject;
  try
    JsonString := TStringList.Create;
    try
      JsonString.Text := JsonObj.ToString;
      JsonString.SaveToFile(FileName);
    finally
      JsonString.Free;
    end;
  finally
    JsonObj.Free;
  end;
end;

procedure TGaussianNaiveBayes.LoadFromFile(const FileName: string);
var
  JsonString: TStringList;
  JsonObj: TJSONObject;
begin
  JsonString := TStringList.Create;
  try
    JsonString.LoadFromFile(FileName);
    JsonObj := TJSONObject.ParseJSONValue(JsonString.Text) as TJSONObject;
    try
      if JsonObj <> nil then begin
        LoadFromJSONObject(JsonObj);  
      end;
    finally
      JsonObj.Free;
    end;
  finally
    JsonString.Free;
  end;
end;

procedure TGaussianNaiveBayes.LoadFromJSONObject(JsonObj: TJSONObject);
var
  MeanObj, VarianceObj: TJSONObject;
  MeanArray, VarianceArray: TJSONArray;
  ClassLabel: string;
  i: Integer;
  TempArray: TAISampleAtr;
  JsonPair: TJSONPair;
begin

  InputLength := StrToInt(JsonObj.FindValue('InputLength').Value);
  JSONToNormRange(JsonObj.FindValue('NormalizationRange') as TJSONObject);
  JsonObj := JsonObj.FindValue('Model') as TJSONObject;

  FClasses := TDictionary<string, Integer>.Create;
  FClassProbabilities := TDictionary<string, Double>.Create;
  FMeans := TDictionary<string, TAISampleAtr>.Create;
  FVariances := TDictionary<string, TAISampleAtr>.Create;

  for JsonPair in JsonObj do begin
    ClassLabel := JsonPair.JsonString.Value;

    if ClassLabel.EndsWith('_count') then begin
      FClasses.AddOrSetValue(ClassLabel.Replace('_count', ''), JsonPair.JsonValue.AsType<Integer>);
    end
    else if ClassLabel.EndsWith('_probability') then begin
      FClassProbabilities.AddOrSetValue(ClassLabel.Replace('_probability', ''), JsonPair.JsonValue.AsType<Double>);
    end;
  end;

  for ClassLabel in FClasses.Keys do begin
    MeanObj := JsonObj.GetValue(ClassLabel + '_mean') as TJSONObject;
    VarianceObj := JsonObj.GetValue(ClassLabel + '_variance') as TJSONObject;

    MeanArray := MeanObj.GetValue('mean') as TJSONArray;
    VarianceArray := VarianceObj.GetValue('variance') as TJSONArray;


    SetLength(TempArray, MeanArray.Count);
    for i := 0 to MeanArray.Count - 1 do
    begin
      TempArray[i] := MeanArray.Items[i].AsType<Double>;
    end;
    FMeans.AddOrSetValue(ClassLabel, TempArray);

    SetLength(TempArray, VarianceArray.Count);
    for i := 0 to VarianceArray.Count - 1 do
    begin
      TempArray[i] := VarianceArray.Items[i].AsType<Double>;
    end;
    FVariances.AddOrSetValue(ClassLabel, TempArray);
  end;

  Trained := True;
end;





end.

