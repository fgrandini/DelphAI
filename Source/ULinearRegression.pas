unit ULinearRegression;

interface

uses
  System.Generics.Collections, System.SysUtils, System.Math,
  System.JSON, UAITypes, UAIModel, Data.DB;

type
  TLinearRegression = class(TRegressionModel)
  private
    FB0: Double;
    FCoefficients: TArray<Double>;
    procedure TrainModel;
  public
    procedure Train(aTrainingData : TAIDatasetRegression; aNormalizationRange : TNormalizationRange); overload;
    procedure Train(aTrainingData : String; aHasHeader : Boolean = True); overload;
    procedure Train(aTrainingData : TDataSet); overload;
    function Predict(aSample: TAISampleAtr; aInputNormalized : Boolean = False): Double;

    function SumVector(const aValues: TArray<Double>): Double;
    function MediaVector(const aValues: TArray<Double>): Double;
    function SumProducts(const X, Y: TArray<Double>): Double;
    function SumSquared(const X: TArray<Double>): Double;

    function ToJson: TJsonObject;
    procedure FromJson(aJson: TJsonObject);
    procedure SaveToFile(const aFileName: string);
    procedure LoadFromFile(const aFileName: string);
  end;

implementation

uses
  System.Classes, UAuxGlobal;

function TLinearRegression.SumVector(const aValues: TArray<Double>): Double;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to High(aValues) do begin
    Result := Result + aValues[i];
  end;
end;

function TLinearRegression.MediaVector(const aValues: TArray<Double>): Double;
begin
  Result := SumVector(aValues) / Length(aValues);
end;

function TLinearRegression.SumProducts(const X, Y: TArray<Double>): Double;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to High(X) do begin
    Result := Result + (X[i] * Y[i]);
  end;
end;

function TLinearRegression.SumSquared(const X: TArray<Double>): Double;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to High(X) do begin
    Result := Result + (X[i] * X[i]);
  end;
end;

procedure TLinearRegression.TrainModel;
var
  X: TArray<TArray<Double>>;
  Y: TArray<Double>;
  vMediasX: TArray<Double>;
  vMediaY: Double;
  i, j: Integer;
  vSumProducts, vSumSquares: Double;
  vAttributes: Integer;
begin
  vAttributes := Length(FDataset[0].Key);

  SetLength(X, Length(FDataset));
  SetLength(Y, Length(FDataset));
  SetLength(vMediasX, vAttributes);
  SetLength(FCoefficients, vAttributes);

  for i := 0 to High(FDataset) do begin
    X[i] := FDataset[i].Key;
    Y[i] := FDataset[i].Value;
  end;

  for j := 0 to vAttributes - 1 do begin
    for i := 0 to High(X) do begin
      vMediasX[j] := vMediasX[j] + X[i][j];
    end;
    vMediasX[j] := vMediasX[j] / Length(X);
  end;

  vMediaY := MediaVector(Y);

  for j := 0 to vAttributes - 1 do begin
    vSumProducts := 0;
    vSumSquares := 0;
    for i := 0 to High(X) do begin
      vSumProducts := vSumProducts + (X[i][j] - vMediasX[j]) * (Y[i] - vMediaY);
      vSumSquares := vSumSquares + Sqr(X[i][j] - vMediasX[j]);
    end;

    FCoefficients[j] := vSumProducts / vSumSquares;
  end;

  FB0 := vMediaY;
  for j := 0 to vAttributes - 1 do begin
    FB0 := FB0 - FCoefficients[j] * vMediasX[j];
  end;

  PopulateInputLenght;
  Trained := True;
end;

procedure TLinearRegression.Train(aTrainingData : TAIDatasetRegression; aNormalizationRange : TNormalizationRange);
begin
  FNormalizationRange := aNormalizationRange;
  FDataset := Copy(aTrainingData);
  TrainModel;
end;

procedure TLinearRegression.Train(aTrainingData : TDataSet);
begin
  if aTrainingData.RecordCount = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;

  LoadDataset(aTrainingData, FDataset, FNormalizationRange);
  TrainModel;

end;

procedure TLinearRegression.Train(aTrainingData : String; aHasHeader: Boolean);
begin
  LoadDataset(aTrainingData, FDataset, FNormalizationRange, aHasHeader);

  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  TrainModel;

end;

function TLinearRegression.Predict(aSample: TAISampleAtr; aInputNormalized : Boolean = False): Double;
var
  i: Integer;
begin
  aSample := Copy(aSample);
  if not aInputNormalized then begin
    ValidateAndNormalizeInput(aSample);
  end;

  Result := FB0;

  for i := 0 to High(FCoefficients) do begin
    Result := Result + FCoefficients[i] * aSample[i];
  end;
end;

function TLinearRegression.ToJson: TJsonObject;
var
  vJsonCoefficients: TJSONArray;
  i: Integer;
  vJsonObj : TJsonObject;
begin
  Result := TJSONObject.Create;
  vJsonObj := TJSONObject.Create;

  Result.AddPair('NormalizationRange', NormRangeToJSON);
  Result.AddPair('InputLength', TJSONNumber.Create(InputLength));
  Result.AddPair('Model', vJsonObj);

  vJsonCoefficients := TJSONArray.Create;

  vJsonObj.AddPair('Intercept', TJSONNumber.Create(FB0));

  for i := 0 to High(FCoefficients) do begin
    vJsonCoefficients.Add(FCoefficients[i]);
  end;

  vJsonObj.AddPair('Coefficients', vJsonCoefficients);
end;

procedure TLinearRegression.FromJson(aJson: TJsonObject);
var
  vJsonCoefficients: TJSONArray;
  i: Integer;
begin
  InputLength := StrToInt(aJson.FindValue('InputLength').Value);
  JSONToNormRange(aJson.FindValue('NormalizationRange') as TJSONObject);
  aJson := aJson.FindValue('Model') as TJSONObject;

  if aJson.TryGetValue<Double>('Intercept', FB0) then begin
    vJsonCoefficients := aJson.GetValue<TJSONArray>('Coefficients');
    SetLength(FCoefficients, vJsonCoefficients.Count);

    for i := 0 to vJsonCoefficients.Count - 1 do begin
      FCoefficients[i] := vJsonCoefficients.Items[i].AsType<Double>;
    end;

    Trained := True;
  end else begin
    raise Exception.Create('Invalid JSON: Intercept not found.');
  end;
end;

procedure TLinearRegression.SaveToFile(const aFileName: string);
var
  vJson: TJsonObject;
  vFileStream: TFileStream;
  vJsonString: TStringStream;
begin
  vJson := ToJson;
  vJsonString := TStringStream.Create(vJson.ToJSON, TEncoding.UTF8);
  try
    vFileStream := TFileStream.Create(aFileName, fmCreate);
    try
      vFileStream.CopyFrom(vJsonString, vJsonString.Size);
    finally
      vFileStream.Free;
    end;
  finally
    vJsonString.Free;
    vJson.Free;
  end;
end;

procedure TLinearRegression.LoadFromFile(const aFileName: string);
var
  vJson: TJsonObject;
  vFileStream: TFileStream;
  vJsonString: TStringStream;
begin
  vFileStream := TFileStream.Create(aFileName, fmOpenRead);
  vJsonString := TStringStream.Create('', TEncoding.UTF8);
  try
    vJsonString.CopyFrom(vFileStream, vFileStream.Size);
    vJson := TJSONObject.ParseJSONValue(vJsonString.DataString) as TJsonObject;
    try
      FromJson(vJson);
    finally
      vJson.Free;
    end;
  finally
    vFileStream.Free;
    vJsonString.Free;
  end;
end;


end.

