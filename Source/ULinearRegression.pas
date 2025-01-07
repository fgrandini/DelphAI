unit ULinearRegression;

interface

uses
  System.Generics.Collections, System.SysUtils, System.Math,
  System.JSON, UAITypes, UAIModel, Data.DB;

type
  TLinearRegression = class(TRegressionModel)
  private
    FB0: Double;
    FCoeficientes: TArray<Double>;
    procedure TrainModel;
  public
    procedure Train(aTrainingData : TAIDatasetRegression; aNormalizationRange : TNormalizationRange); overload;
    procedure Train(aTrainingData : String; aHasHeader : Boolean = True); overload;
    procedure Train(aTrainingData : TDataSet); overload;
    function Predict(aSample: TAISampleAtr; aInputNormalized : Boolean = False): Double;

    function ToJson: TJsonObject;
    procedure FromJson(aJson: TJsonObject);
    procedure SaveToFile(const FileName: string);
    procedure LoadFromFile(const FileName: string);
  end;

implementation

uses
  System.Classes, UAuxGlobal;

function SomarVetor(const Valores: TArray<Double>): Double;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to High(Valores) do begin
    Result := Result + Valores[i];
  end;
end;

function MediaVetor(const Valores: TArray<Double>): Double;
begin
  Result := SomarVetor(Valores) / Length(Valores);
end;

function SomatorioProdutos(const X, Y: TArray<Double>): Double;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to High(X) do begin
    Result := Result + (X[i] * Y[i]);
  end;
end;

function SomatorioQuadrados(const X: TArray<Double>): Double;
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
  mediasX: TArray<Double>;
  mediaY: Double;
  i, j: Integer;
  somatorioProdutos, somatorioQuadrados: Double;
  nAtributos: Integer;
begin
  nAtributos := Length(FDataset[0].Key); 

  SetLength(X, Length(FDataset));
  SetLength(Y, Length(FDataset));
  SetLength(mediasX, nAtributos);
  SetLength(FCoeficientes, nAtributos);

  for i := 0 to High(FDataset) do begin
    X[i] := FDataset[i].Key;
    Y[i] := FDataset[i].Value;
  end;

  for j := 0 to nAtributos - 1 do begin
    for i := 0 to High(X) do begin
      mediasX[j] := mediasX[j] + X[i][j];
    end;
    mediasX[j] := mediasX[j] / Length(X);
  end;

  mediaY := MediaVetor(Y);

  for j := 0 to nAtributos - 1 do begin
    somatorioProdutos := 0;
    somatorioQuadrados := 0;
    for i := 0 to High(X) do begin
      somatorioProdutos := somatorioProdutos + (X[i][j] - mediasX[j]) * (Y[i] - mediaY);
      somatorioQuadrados := somatorioQuadrados + Sqr(X[i][j] - mediasX[j]);
    end;

    FCoeficientes[j] := somatorioProdutos / somatorioQuadrados;
  end;

  FB0 := mediaY;
  for j := 0 to nAtributos - 1 do begin
    FB0 := FB0 - FCoeficientes[j] * mediasX[j];
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

  for i := 0 to High(FCoeficientes) do begin
    Result := Result + FCoeficientes[i] * aSample[i];
  end;
end;

function TLinearRegression.ToJson: TJsonObject;
var
  JsonCoeficientes: TJSONArray;
  i: Integer;
  JsonObj : TJsonObject;
begin
  Result := TJSONObject.Create;
  JsonObj := TJSONObject.Create;

  Result.AddPair('NormalizationRange', NormRangeToJSON);
  Result.AddPair('InputLength', InputLength);
  Result.AddPair('Model', JsonObj);

  JsonCoeficientes := TJSONArray.Create;

  JsonObj.AddPair('Intercept', TJSONNumber.Create(FB0));

  for i := 0 to High(FCoeficientes) do begin
    JsonCoeficientes.Add(FCoeficientes[i]);
  end;

  JsonObj.AddPair('Coefficients', JsonCoeficientes);
end;

procedure TLinearRegression.FromJson(aJson: TJsonObject);
var
  JsonCoeficientes: TJSONArray;
  i: Integer;
begin
  InputLength := StrToInt(aJson.FindValue('InputLength').Value);
  JSONToNormRange(aJson.FindValue('NormalizationRange') as TJSONObject);
  aJson := aJson.FindValue('Model') as TJSONObject;

  if aJson.TryGetValue<Double>('Intercept', FB0) then begin
    JsonCoeficientes := aJson.GetValue<TJSONArray>('Coefficients');
    SetLength(FCoeficientes, JsonCoeficientes.Count);

    for i := 0 to JsonCoeficientes.Count - 1 do begin
      FCoeficientes[i] := JsonCoeficientes.Items[i].AsType<Double>;
    end;

    Trained := True;
  end else begin
    raise Exception.Create('JSON inválido: Intercepto não encontrado.');
  end;
end;

procedure TLinearRegression.SaveToFile(const FileName: string);
var
  Json: TJsonObject;
  FileStream: TFileStream;
  JsonString: TStringStream;
begin
  Json := ToJson;
  JsonString := TStringStream.Create(Json.ToJSON, TEncoding.UTF8);
  try
    FileStream := TFileStream.Create(FileName, fmCreate);
    try
      FileStream.CopyFrom(JsonString, JsonString.Size);
    finally
      FileStream.Free;
    end;
  finally
    JsonString.Free;
    Json.Free;
  end;
end;

procedure TLinearRegression.LoadFromFile(const FileName: string);
var
  Json: TJsonObject;
  FileStream: TFileStream;
  JsonString: TStringStream;
begin
  FileStream := TFileStream.Create(FileName, fmOpenRead);
  JsonString := TStringStream.Create('', TEncoding.UTF8);
  try
    JsonString.CopyFrom(FileStream, FileStream.Size);
    Json := TJSONObject.ParseJSONValue(JsonString.DataString) as TJsonObject;
    try
      FromJson(Json);
    finally
      Json.Free;
    end;
  finally
    FileStream.Free;
    JsonString.Free;
  end;
end;


end.

