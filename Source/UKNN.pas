unit UKNN;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  System.Math,
  Data.DB,
  UAITypes,
  UAIModel;

type
  { TKNNPrediction }
  TKNNClassification = class(TClassificationModel)
  private
    FK : Integer;
    function GetKs(const aDistances: TArray<Double>): TArray<string>;
  public
    constructor Create(aTrainingData : TAIDatasetClassification; aNormalizationRange : TNormalizationRange; aK: Integer); overload;
    constructor Create(aTrainingData : String; aK: Integer; aHasHeader : Boolean = True); overload;
    constructor Create(aTrainingData : TDataSet; aK: Integer); overload;
    function Predict(aSample : TAISampleAtr; aInputNormalized : Boolean = False): string;
  end;

  { TKNNRegression }
  TKNNRegression = class(TRegressionModel)
  private
    FK : Integer;
    function GetKs(const aDistances: TArray<Double>): TArray<Double>;
    class procedure ValidateK(aK : Integer);
  public
    constructor Create(aTrainingData : TAIDatasetRegression; aNormalizationRange : TNormalizationRange; aK : Integer); overload;
    constructor Create(aTrainingData : String; aK: Integer; aHasHeader : Boolean = True); overload;
    constructor Create(aTrainingData : TDataSet; aK: Integer); overload;
    function Predict(aSample : TAISampleAtr; aInputNormalized : Boolean = False): Double;
  end;

implementation

uses
  UAuxGlobal,
  System.Generics.Defaults;

function TKNNRegression.GetKs(const aDistances: TArray<Double>): TArray<Double>;
var
  i: Integer;
  vKNearest: TArray<Double>;
  vDistancesWithIndices: TArray<TPair<Double, Integer>>;
begin
  SetLength(vDistancesWithIndices, Length(aDistances));
  for i := 0 to High(aDistances) do begin
    vDistancesWithIndices[i] := TPair<Double, Integer>.Create(aDistances[i], i);
  end;

  TArray.Sort<TPair<Double, Integer>>(vDistancesWithIndices, TComparer<TPair<Double, Integer>>.Construct(
    function(const L, R: TPair<Double, Integer>): Integer
    begin
      Result := CompareValue(L.Key, R.Key);
    end));

  SetLength(vKNearest, FK);
  for i := 0 to FK - 1 do begin
    vKNearest[i] := FDataset[vDistancesWithIndices[i].Value].Value;
  end;

  Result := vKNearest;
end;

function TKNNRegression.Predict(aSample: TAISampleAtr; aInputNormalized : Boolean = False): Double;
var
  vDistances: TArray<Double>;
  vNeighbors: TArray<Double>;
  i: Integer;
  vSumNeighbors, vMedia: Double;
begin
  aSample := Copy(aSample);
  if not aInputNormalized then begin
    ValidateAndNormalizeInput(aSample);
  end;
  SetLength(vDistances, Length(FDataset));

  for i := 0 to High(FDataset) do begin
    vDistances[i] := CalculateEuclideanDistance(aSample, FDataset[i].Key);
  end;

  vNeighbors := GetKs(vDistances);

  vSumNeighbors := 0;
  for i := 0 to High(vNeighbors) do begin
    vSumNeighbors := vSumNeighbors + vNeighbors[i];
  end;

  vMedia := vSumNeighbors / FK;
  Result := vMedia;
end;

class procedure TKNNRegression.ValidateK(aK : Integer);
begin
  if not Odd(aK) then begin
    raise Exception.CreateFmt('Error: The value of K (%d) must be an odd number. Please provide an odd value.', [aK]);
  end;
end;

constructor TKNNClassification.Create(aTrainingData: TAIDatasetClassification; aNormalizationRange : TNormalizationRange; aK: Integer);
begin
  TKNNRegression.ValidateK(aK);

  FNormalizationRange := aNormalizationRange;
  FDataset := Copy(aTrainingData);

  Trained := True;
  PopulateInputLenght;
  FK := aK;
end;

constructor TKNNClassification.Create(aTrainingData: TDataSet; aK: Integer);
begin
  TKNNRegression.ValidateK(aK);

  LoadDataset(aTrainingData, FDataset, FNormalizationRange);

  Trained := True;
  PopulateInputLenght;
  FK := aK;
end;

constructor TKNNClassification.Create(aTrainingData: String; aK: Integer; aHasHeader: Boolean);
begin
  TKNNRegression.ValidateK(aK);

  LoadDataset(aTrainingData, FDataset, FNormalizationRange, aHasHeader);

  Trained := True;
  PopulateInputLenght;
  FK := aK;
end;

function TKNNClassification.GetKs(const aDistances: TArray<Double>): TArray<string>;
var
  i: Integer;
  vKNearest: TArray<string>;
  vDistancesWithIndices: TArray<TPair<Double, Integer>>;
begin
  SetLength(vDistancesWithIndices, Length(aDistances));
  for i := 0 to High(aDistances) do begin
    vDistancesWithIndices[i] := TPair<Double, Integer>.Create(aDistances[i], i);
  end;


  TArray.Sort<TPair<Double, Integer>>(vDistancesWithIndices, TComparer<TPair<Double, Integer>>.Construct(
    function(const L, R: TPair<Double, Integer>): Integer
    begin
      Result := CompareValue(L.Key, R.Key);
    end));

  SetLength(vKNearest, FK);
  for i := 0 to FK - 1 do begin
    vKNearest[i] := FDataset[vDistancesWithIndices[i].Value].Value;
  end;

  Result := vKNearest;
end;

function TKNNClassification.Predict(aSample: TAISampleAtr; aInputNormalized : Boolean = False): string;
var
  vDistances: TArray<Double>;
  vNeighbors: TArray<string>;
  i: Integer;
  vNearestClass: string;
  vContClasses: TDictionary<string, Integer>;
  vMaxCount, vCurrentCount: Integer;
  vClass: string;
begin
  aSample := Copy(aSample);
  if not aInputNormalized then begin
    ValidateAndNormalizeInput(aSample);
  end;
  SetLength(vDistances, Length(FDataset));

  for i := 0 to High(FDataset) do begin
    vDistances[i] := CalculateEuclideanDistance(aSample, FDataset[i].Key);
  end;

  vNeighbors := GetKs(vDistances);

  vContClasses := TDictionary<string, Integer>.Create;
  try
    for i := 0 to High(vNeighbors) do begin
      vClass := vNeighbors[i];
      if vContClasses.ContainsKey(vClass) then
        vContClasses[vClass] := vContClasses[vClass] + 1
      else
        vContClasses.Add(vClass, 1);
    end;

    vMaxCount := -1;
    for vClass in vContClasses.Keys do begin
      vCurrentCount := vContClasses[vClass];
      if vCurrentCount > vMaxCount then begin
        vMaxCount := vCurrentCount;
        vNearestClass := vClass;
      end;
    end;
  finally
    vContClasses.Free;
  end;

  Result := vNearestClass;
end;

{ TKNNRegression }

constructor TKNNRegression.Create(aTrainingData : TAIDatasetRegression; aNormalizationRange : TNormalizationRange; aK: Integer);
begin
  ValidateK(aK);

  FNormalizationRange := aNormalizationRange;
  FDataset := Copy(aTrainingData);

  Trained := True;
  PopulateInputLenght;
  FK := aK;
end;

constructor TKNNRegression.Create(aTrainingData : TDataSet; aK: Integer);
begin
  ValidateK(aK);

  LoadDataset(aTrainingData, FDataset, FNormalizationRange);

  Trained := True;
  PopulateInputLenght;
  FK := aK;
end;

constructor TKNNRegression.Create(aTrainingData: String; aK: Integer; aHasHeader: Boolean);
begin
  ValidateK(aK);

  LoadDataset(aTrainingData, FDataset, FNormalizationRange, aHasHeader);

  Trained := True;
  PopulateInputLenght;
  FK := aK;
end;

end.

