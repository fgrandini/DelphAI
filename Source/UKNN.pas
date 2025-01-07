unit UKNN;

interface

uses
  System.Generics.Collections, System.SysUtils, System.Math, Data.DB, UAITypes, UAIModel;

type
  { TKNNPrediction }
  TKNNClassification = class(TClassificationModel)
  private
    FK : Integer;
    function GetKs(const aDistancias: TArray<Double>): TArray<string>;
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
    function GetKs(const aDistancias: TArray<Double>): TArray<Double>;
  public
    constructor Create(aTrainingData : TAIDatasetRegression; aNormalizationRange : TNormalizationRange; aK : Integer); overload;
    constructor Create(aTrainingData : String; aK: Integer; aHasHeader : Boolean = True); overload;
    constructor Create(aTrainingData : TDataSet; aK: Integer); overload;
    function Predict(aSample : TAISampleAtr; aInputNormalized : Boolean = False): Double;
  end;

implementation

uses
  UAuxGlobal, System.Generics.Defaults;


function TKNNRegression.GetKs(const aDistancias: TArray<Double>): TArray<Double>;
var
  i: Integer;
  KMaisProximos: TArray<Double>;
  DistanciasComIndices: TArray<TPair<Double, Integer>>;
begin
  SetLength(DistanciasComIndices, Length(aDistancias));
  for i := 0 to High(aDistancias) do begin
    DistanciasComIndices[i] := TPair<Double, Integer>.Create(aDistancias[i], i);
  end;

  TArray.Sort<TPair<Double, Integer>>(DistanciasComIndices, TComparer<TPair<Double, Integer>>.Construct(
    function(const L, R: TPair<Double, Integer>): Integer
    begin
      Result := CompareValue(L.Key, R.Key);
    end));

  SetLength(KMaisProximos, FK);
  for i := 0 to FK - 1 do begin
    KMaisProximos[i] := FDataset[DistanciasComIndices[i].Value].Value;
  end;

  Result := KMaisProximos;
end;

function TKNNRegression.Predict(aSample: TAISampleAtr; aInputNormalized : Boolean = False): Double;
var
  aDistancias: TArray<Double>;
  vizinhos: TArray<Double>;
  i: Integer;
  somaVizinhos, media: Double;
begin
  aSample := Copy(aSample);
  if not aInputNormalized then begin
    ValidateAndNormalizeInput(aSample);
  end;
  SetLength(aDistancias, Length(FDataset));

  
  for i := 0 to High(FDataset) do begin
    aDistancias[i] := CalcularDistanciaEuclidiana(aSample, FDataset[i].Key);
  end;

  vizinhos := GetKs(aDistancias);

  
  somaVizinhos := 0;
  for i := 0 to High(vizinhos) do begin
    somaVizinhos := somaVizinhos + vizinhos[i];
  end;

  media := somaVizinhos / FK;

  Result := media; 
end;

procedure ValidaK(aK : Integer);
begin
  if not Odd(aK) then begin
    raise Exception.CreateFmt('Error: The value of K (%d) must be an odd number. Please provide an odd value.', [aK]);
  end;
end;

constructor TKNNClassification.Create(aTrainingData: TAIDatasetClassification; aNormalizationRange : TNormalizationRange; aK: Integer);
begin
  ValidaK(aK);

  FNormalizationRange := aNormalizationRange;
  FDataset := Copy(aTrainingData);

  Trained := True;
  PopulateInputLenght;
  FK := aK;
end;

constructor TKNNClassification.Create(aTrainingData: TDataSet; aK: Integer);
begin
  ValidaK(aK);

  LoadDataset(aTrainingData, FDataset, FNormalizationRange);

  Trained := True;
  PopulateInputLenght;
  FK := aK;
end;

constructor TKNNClassification.Create(aTrainingData: String; aK: Integer; aHasHeader: Boolean);
begin
  ValidaK(aK);

  LoadDataset(aTrainingData, FDataset, FNormalizationRange, aHasHeader);

  Trained := True;
  PopulateInputLenght;
  FK := aK;
end;

function TKNNClassification.GetKs(const aDistancias: TArray<Double>): TArray<string>;
var
  i: Integer;
  KMaisProximos: TArray<string>;
  DistanciasComIndices: TArray<TPair<Double, Integer>>;
begin
  SetLength(DistanciasComIndices, Length(aDistancias));
  for i := 0 to High(aDistancias) do begin
    DistanciasComIndices[i] := TPair<Double, Integer>.Create(aDistancias[i], i);
  end;

  
  TArray.Sort<TPair<Double, Integer>>(DistanciasComIndices, TComparer<TPair<Double, Integer>>.Construct(
    function(const L, R: TPair<Double, Integer>): Integer
    begin
      Result := CompareValue(L.Key, R.Key);
    end));

  SetLength(KMaisProximos, FK);
  for i := 0 to FK - 1 do begin
    KMaisProximos[i] := FDataset[DistanciasComIndices[i].Value].Value;
  end;

  Result := KMaisProximos;
end;


function TKNNClassification.Predict(aSample: TAISampleAtr; aInputNormalized : Boolean = False): string;
var
  aDistancias: TArray<Double>;
  vVizinhos: TArray<string>;
  i: Integer;
  vClasseMaisProxima: string;
  vContClasses: TDictionary<string, Integer>;
  vMaxCount, vCurrentCount: Integer;
  vClasse: string;
begin
  aSample := Copy(aSample);
  if not aInputNormalized then begin
    ValidateAndNormalizeInput(aSample);
  end;
  SetLength(aDistancias, Length(FDataset));

  
  for i := 0 to High(FDataset) do begin
    aDistancias[i] := CalcularDistanciaEuclidiana(aSample, FDataset[i].Key);
  end;

  
  vVizinhos := GetKs(aDistancias);

  
  vContClasses := TDictionary<string, Integer>.Create;
  try
    for i := 0 to High(vVizinhos) do begin
      vClasse := vVizinhos[i];
      if vContClasses.ContainsKey(vClasse) then
        vContClasses[vClasse] := vContClasses[vClasse] + 1
      else
        vContClasses.Add(vClasse, 1);
    end;

    
    vMaxCount := -1;
    for vClasse in vContClasses.Keys do begin
      vCurrentCount := vContClasses[vClasse];
      if vCurrentCount > vMaxCount then begin
        vMaxCount := vCurrentCount;
        vClasseMaisProxima := vClasse;
      end;
    end;
  finally
    vContClasses.Free;
  end;

  Result := vClasseMaisProxima; 
end;


{ TKNNRegression }


constructor TKNNRegression.Create(aTrainingData : TAIDatasetRegression; aNormalizationRange : TNormalizationRange; aK: Integer);
begin
  ValidaK(aK);

  FNormalizationRange := aNormalizationRange;
  FDataset := Copy(aTrainingData);

  Trained := True;
  PopulateInputLenght;
  FK := aK;
end;

constructor TKNNRegression.Create(aTrainingData : TDataSet; aK: Integer);
begin
  ValidaK(aK);

  LoadDataset(aTrainingData, FDataset, FNormalizationRange);

  Trained := True;
  PopulateInputLenght;
  FK := aK;
end;

constructor TKNNRegression.Create(aTrainingData: String; aK: Integer; aHasHeader: Boolean);
begin
  ValidaK(aK);

  LoadDataset(aTrainingData, FDataset, FNormalizationRange, aHasHeader);

  Trained := True;
  PopulateInputLenght;
  FK := aK;
end;

end.

