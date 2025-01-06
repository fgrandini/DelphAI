unit UAuxGlobal;

interface
uses
  UKNN, UAISelector, Data.DB, UAITypes, System.Generics.Collections;

type

  TAIDatasetGeneric = TArray<TAISampleClassification>;

  function CalcularDistanciaEuclidiana(const pontoA, pontoB: TAISampleAtr): Double;
  function SplitLabelAndSampleDataset(const ADataset: TAIDatasetClassification; out ASamples: TAISamplesAtr; out ALabels: TAILabelsClassification): Boolean; overload;
  function SplitLabelAndSampleDataset(const ADataset: TAIDatasetRegression; out ASamples: TAISamplesAtr; out ALabels: TAILabelsRegression): Boolean; overload;

  function LoadDataset(const aFileName: String; out Data: TAIDatasetRegression; out aNormalizationRange : TNormalizationRange; aHaveHeader : Boolean = True): Boolean; overload;
  function LoadDataset(const aFileName: String; out Data: TAIDatasetClassification; out aNormalizationRange : TNormalizationRange; aHaveHeader : Boolean = True): Boolean; overload;
  function LoadDataset(const aFileName: String; out Data: TArray<TAISampleAtr>; out aNormalizationRange : TNormalizationRange; aHaveHeader: Boolean = True): Boolean; overload;

  function LoadDataset(const aDataSet : TDataSet; out Data: TAIDatasetRegression; out aNormalizationRange : TNormalizationRange): Boolean; overload;
  function LoadDataset(const aDataSet : TDataSet; out Data: TAIDatasetClassification; out aNormalizationRange : TNormalizationRange): Boolean; overload;
  function LoadDataset(const aDataSet : TDataSet; out Data: TArray<TAISampleAtr>; out aNormalizationRange : TNormalizationRange): Boolean; overload;

  function IndexOfMax(const values: TArray<Double>): Integer; overload;
  function IndexOfMax(const values: array of Single): Integer; overload;

  function GetRandomValues(const aLimit, X: Integer): TDictionary<Integer, Boolean>;

  procedure NormalizeSamples(var Data: TAISamplesAtr; const NormRange: TNormalizationRange);
  function NormalizeDataset(var Data: TAIDatasetRegression) : TNormalizationRange; overload;
  function NormalizeDataset(var Data: TAIDatasetClassification) : TNormalizationRange; overload;
  function NormalizeDataset(var Data: TArray<TAISampleAtr>) : TNormalizationRange; overload;

  function SplitCriterionToString(aSplitCrit : TSplitCriterion) : String;
  function DistanceMethodToStr(Mode: TDistanceMode): string;
  function AggregModeToStr(Method: TUserScoreAggregationMethod): string;

  function PCThreadCount : Integer;
  procedure CleanObjectList(aList : TList<TObject>);

implementation

uses
  System.SysUtils, Graphics, Winapi.Windows, System.Classes, System.Math;

function IfStr(aResultado : Boolean; aTextoSeTrue, aTextoSeFalse : String) : String;
begin
   if aResultado then begin
     Result := aTextoSeTrue
   end else begin
     Result := aTextoSeFalse;
   end;
end;

function CalcularDistanciaEuclidiana(const pontoA, pontoB: TAISampleAtr): Double;
var
  i: Integer;
  vSoma: Double;
begin
  vSoma := 0.0;
  for i := 0 to Length(pontoA) - 1 do begin
    vSoma := vSoma + Sqr(pontoA[i] - pontoB[i]);
  end;
  Result := Sqrt(vSoma);
end;

function SplitLabelAndSampleDataset(const ADataset: TAIDatasetClassification; out ASamples: TAISamplesAtr; out ALabels: TAILabelsClassification): Boolean;
var
  I: Integer;
begin
  Result := False;

  if Length(ADataset) = 0 then begin
    Exit;
  end;

  SetLength(ASamples, Length(ADataset));
  SetLength(ALabels, Length(ADataset));

  for I := 0 to High(ADataset) do
  begin
    ASamples[I] := ADataset[I].Key;
    ALabels[I] := ADataset[I].Value;
  end;

  Result := True;
end;

function SplitLabelAndSampleDataset(const ADataset: TAIDatasetRegression; out ASamples: TAISamplesAtr; out ALabels: TAILabelsRegression): Boolean;
var
  I: Integer;
begin
  Result := False;

  if Length(ADataset) = 0 then begin
    Exit;
  end;

  SetLength(ASamples, Length(ADataset));
  SetLength(ALabels, Length(ADataset));

  for I := 0 to High(ADataset) do
  begin
    ASamples[I] := ADataset[I].Key;
    ALabels[I] := ADataset[I].Value;
  end;

  Result := True;
end;

function LoadGenericDataSetQuery(const aDataSet : TDataSet; out Data: TAIDatasetGeneric; aClassification : Boolean = False) : Boolean;
 var
  vClasse: string;
  vPonto: TAISampleAtr;
  vRecordCount,
  i, j : Integer;

  procedure GeraMensagemErro(aMsgExtra : String; aLinha, aColuna : Integer);
  begin
    raise Exception.Create('Error reading Dataset.' +
                           ' Line: ' + IntToStr(aLinha + 1) + ', Column ' + IntToStr(aColuna + 1) + '. ' +
                           aMsgExtra);
  end;

begin                                   
  aDataSet.First;

  // Calculate record count because TDataSet.RecordCount have a native bug with TFDQuery.
  vRecordCount := 0;
  while not aDataSet.Eof do begin
    aDataSet.Next;
    inc(vRecordCount);
  end;
  
  SetLength(Data, vRecordCount);
  aDataSet.First;
  for i := 0 to Length(Data) - 1 do begin
    SetLength(vPonto, aDataSet.FieldCount - 1);
    for j := 0 to Length(vPonto) - 1 do begin
      try
        vPonto[j] := aDataSet.FieldByName(aDataSet.Fields[j].FieldName).AsCurrency;
      except
        on E:EConvertError do begin
          GeraMensagemErro('Please verify if all columns' + ifStr(aClassification, ' (except the last one)', '') +
                           ' contain only float values. Error: ' + E.Message, i, j);
        end;
        on E:Exception do begin
          GeraMensagemErro('Error: ' + E.Message, i, j);
        end;
      end;
    end;
    try
      vClasse := aDataSet.FieldByName(aDataSet.Fields[aDataSet.FieldCount - 1].FieldName).AsString;
      if not aClassification then begin
        StrToFloat(vClasse);
      end;
    except
        on E:EConvertError do begin
          GeraMensagemErro('Please verify if all columns' + ifStr(aClassification, ' (except the last one)', '') +
                           ' contain only float values. Error: ' + E.Message, i, aDataSet.FieldCount - 1);
        end;
        on E:Exception do begin
          GeraMensagemErro('Error: ' + E.Message, i, aDataSet.FieldCount - 1);
        end;
    end;
    Data[i] := TAISampleClassification.Create(vPonto, vClasse);
    aDataSet.Next;
  end;
  Result := True;
end;

function LoadGenericDataSetFile(const FileName: String; out Data: TAIDatasetGeneric; aHaveHeader : Boolean = True; aClassification : Boolean = False) : Boolean;
 var
  vLista: TStringList;
  vLinha,
  vClasse: string;
  Campos: TAILabelsClassification;
  vPonto: TAISampleAtr;
  vInicio, i, j : Integer;

  procedure GeraMensagemErro(aMsgExtra : String; aLinha, aColuna : Integer);
  begin
    raise Exception.Create('Error reading Dataset.' +
                           ' Line: ' + IntToStr(aLinha + 1) + ', Column ' + IntToStr(aColuna + 1) + '. ' +
                           aMsgExtra);
  end;

begin
  vLista := TStringList.Create;
  try
    vLista.LoadFromFile(FileName);
    if aHaveHeader then begin
      vInicio := 1;
    end else begin
      vInicio := 0;
    end;
    i := vInicio;
    while i < vLista.Count do begin
      vLinha := vLista[i];
      if Trim(vLinha) = '' then begin
        vLista.Delete(i);
      end else begin
        inc(i);
      end;
    end;
    SetLength(Data, vLista.Count - vInicio);
    for i := vInicio to vLista.Count - 1 do begin
      vLinha := vLista[i];

      Campos := vLinha.Split([',']);
      SetLength(vPonto, Length(Campos) - 1);
      for j := 0 to Length(vPonto) - 1 do begin
        try
          vPonto[j] := StrToFloat(StringReplace(Campos[j], '.', ',', []));
        except
          on E:EConvertError do begin
            GeraMensagemErro('Please verify if all columns' + ifStr(aClassification, ' (except the last one)', '') +
                             ' contain only float values. Error: ' + E.Message, i, j);
          end;
          on E:Exception do begin
            GeraMensagemErro('Error: ' + E.Message, i, j);
          end;
        end;
      end;
      try
        vClasse := Campos[Length(Campos) - 1];
        if not aClassification then begin
          StrToFloat(StringReplace(vClasse, '.', ',', []));
        end;
      except
          on E:EConvertError do begin
            GeraMensagemErro('Please verify if all columns' + ifStr(aClassification, ' (except the last one)', '') +
                             ' contain only float values. Error: ' + E.Message, i, Length(Campos) - 1);
          end;
          on E:Exception do begin
            GeraMensagemErro('Error: ' + E.Message, i, Length(Campos) - 1);
          end;
      end;
      Data[i - vInicio] := TAISampleClassification.Create(vPonto, vClasse);
    end;
    Result := True;
  finally
    vLista.Free;
  end;
end;

function LoadDataset(const aFileName: String; out Data: TAIDatasetClassification; out aNormalizationRange : TNormalizationRange; aHaveHeader : Boolean = True): Boolean;
var
  vDataGeneric : TAIDatasetGeneric;
begin
  Result := LoadGenericDataSetFile(aFileName, vDataGeneric, aHaveHeader, True);
   if Result then begin
    Data := vDataGeneric;
    aNormalizationRange := NormalizeDataset(Data);
  end;
end;

function LoadDataset(const aFileName: String; out Data: TAIDatasetRegression; out aNormalizationRange : TNormalizationRange; aHaveHeader : Boolean = True): Boolean;
var
  vDataGeneric : TAIDatasetGeneric;
  i : Integer;
begin
  Result := LoadGenericDataSetFile(aFileName, vDataGeneric, aHaveHeader);
   if Result then begin
    SetLength(Data, Length(vDataGeneric));
    for i := 0 to High(vDataGeneric) do begin
      Data[i] := TPair<TAISampleAtr, Double>.Create(vDataGeneric[i].Key, StrToCurr(StringReplace(vDataGeneric[i].Value, '.', ',', [])));
    end;
    aNormalizationRange := NormalizeDataset(Data);
  end;
end;

function LoadDataset(const aFileName: String; out Data: TArray<TAISampleAtr>; out aNormalizationRange : TNormalizationRange; aHaveHeader: Boolean = True): Boolean;
var
  vDataGeneric : TAIDatasetGeneric;
  i : Integer;
begin
  Result := LoadGenericDataSetFile(aFileName, vDataGeneric, aHaveHeader);
  Result := Result and (Length(vDataGeneric) > 0);
   if Result then begin
    SetLength(Data, Length(vDataGeneric), Length(vDataGeneric[0].Key) + 1);
    for i := 0 to High(vDataGeneric) do begin
      Data[i] := vDataGeneric[i].Key;
      SetLength(Data[i], Length(Data[i]) + 1);
      Data[i][High(Data[i])] := StrToCurr(StringReplace(vDataGeneric[i].Value, '.', ',', []));
    end;
    aNormalizationRange := NormalizeDataset(Data);
  end;
end;

function IndexOfMax(const values: TArray<Double>): Integer;
var
  i, maxIndex: Integer;
  maxValue: Double;
begin
  if Length(values) = 0 then begin
    raise Exception.Create('Array vazio.');
  end;

  maxIndex := 0;
  maxValue := values[0];

  for i := 1 to High(values) do begin
    if values[i] > maxValue then begin
      maxValue := values[i];
      maxIndex := i;
    end;
  end;

  Result := maxIndex;
end;

function IndexOfMax(const values: array of Single): Integer;
var
  i, maxIndex: Integer;
  maxValue: Double;
begin
  if Length(values) = 0 then begin
    raise Exception.Create('Array vazio.');
  end;

  maxIndex := 0;
  maxValue := values[0];

  for i := 1 to High(values) do begin
    if values[i] > maxValue then begin
      maxValue := values[i];
      maxIndex := i;
    end;
  end;

  Result := maxIndex;
end;

function LoadDataset(const aDataset: TDataset; out Data: TAIDatasetClassification; out aNormalizationRange : TNormalizationRange): Boolean;
var
  vDataGeneric : TAIDatasetGeneric;
begin
  Result := LoadGenericDataSetQuery(aDataset, vDataGeneric, True);
   if Result then begin
    Data := vDataGeneric;
    aNormalizationRange := NormalizeDataset(Data);
  end;
end;

function LoadDataset(const aDataset: TDataset; out Data: TAIDatasetRegression; out aNormalizationRange : TNormalizationRange): Boolean;
var
  vDataGeneric : TAIDatasetGeneric;
  i : Integer;
begin
  Result := LoadGenericDataSetQuery(aDataset, vDataGeneric);
   if Result then begin
    SetLength(Data, Length(vDataGeneric));
      for i := 0 to High(vDataGeneric) do begin
        Data[i] := TPair<TAISampleAtr, Double>.Create(vDataGeneric[i].Key, StrToCurr(StringReplace(vDataGeneric[i].Value, '.', ',', [])));
      end;
    aNormalizationRange := NormalizeDataset(Data);
  end;
end;

function LoadDataset(const aDataset: TDataset; out Data: TArray<TAISampleAtr>; out aNormalizationRange : TNormalizationRange): Boolean;
var
  vDataGeneric : TAIDatasetGeneric;
  i : Integer;
begin
  Result := LoadGenericDataSetQuery(aDataset, vDataGeneric);
   if Result then begin
    SetLength(Data, Length(vDataGeneric), Length(vDataGeneric[0].Key) + 1);
    for i := 0 to High(vDataGeneric) do begin
      Data[i] := vDataGeneric[i].Key;
      Data[i][High(Data[i])] := StrToCurr(StringReplace(vDataGeneric[i].Value, '.', ',', []));
    end;
    aNormalizationRange := NormalizeDataset(Data);
  end;
end;

function GetRandomValues(const aLimit, X: Integer): TDictionary<Integer, Boolean>;
var
  vNum: Integer;
begin
  if X > aLimit + 1 then begin
    raise Exception.Create('Não é possível gerar tantos números únicos dentro do limite especificado.');
  end;

  Result := TDictionary<Integer, Boolean>.Create;
  Randomize;

  while Result.Count < X do begin
    vNum := Random(aLimit + 1); 

    if not Result.ContainsKey(vNum) then begin
      Result.Add(vNum, True);
    end;
  end;
end;


function CalculateMinAndMax(const Data: TAISamplesAtr): TNormalizationRange;
var
  SampleCount, i, j: Integer;
begin
  SampleCount := Length(Data);

  if SampleCount = 0 then
    Exit;

  SetLength(Result.MinValues, Length(Data[0]));
  SetLength(Result.MaxValues, Length(Data[0]));

  for j := 0 to High(Data[0]) do
  begin
    Result.MinValues[j] := Data[0][j];
    Result.MaxValues[j] := Data[0][j];
  end;

  for i := 1 to SampleCount - 1 do
    for j := 0 to High(Data[i]) do
    begin
      Result.MinValues[j] := Min(Result.MinValues[j], Data[i][j]);
      Result.MaxValues[j] := Max(Result.MaxValues[j], Data[i][j]);
    end;
end;

procedure NormalizeSamples(var Data: TAISamplesAtr; const NormRange: TNormalizationRange);
var
  i, j: Integer;
begin
  for i := 0 to High(Data) do begin
    for j := 0 to High(Data[i]) do begin
      if (NormRange.MaxValues[j] - NormRange.MinValues[j]) <> 0 then begin
        Data[i][j] := (Data[i][j] - NormRange.MinValues[j]) / (NormRange.MaxValues[j] - NormRange.MinValues[j])
      end else begin
        Data[i][j] := 0; 
      end;
    end;
  end;
end;

function NormalizeDataset(var Data: TArray<TAISampleAtr>) : TNormalizationRange;
begin
  Result := CalculateMinAndMax(Data);
  NormalizeSamples(Data, Result);
end;

function NormalizeDataset(var Data: TAIDatasetRegression) : TNormalizationRange;
var
  Samples: TAISamplesAtr;
  i: Integer;
begin
  SetLength(Samples, Length(Data));
  for i := 0 to High(Data) do begin
    Samples[i] := Data[i].Key;
  end;

  Result := CalculateMinAndMax(Samples);
  NormalizeSamples(Samples, Result);

  for i := 0 to High(Data) do begin
    Data[i] := TPair<TAISampleAtr, Double>.Create(Samples[i], Data[i].Value);
  end;
end;

function NormalizeDataset(var Data: TAIDatasetClassification) : TNormalizationRange;
var
  Samples: TAISamplesAtr;
  i: Integer;
begin
  SetLength(Samples, Length(Data));
  for i := 0 to High(Data) do begin
    Samples[i] := Data[i].Key;
  end;

  Result := CalculateMinAndMax(Samples);
  NormalizeSamples(Samples, Result);

  for i := 0 to High(Data) do begin
    Data[i] := TPair<TAISampleAtr, String>.Create(Samples[i], Data[i].Value);
  end;
end;

function SplitCriterionToString(aSplitCrit : TSplitCriterion) : String;
begin
  Result := '';
  if aSplitCrit = scGini then begin
    Result := 'Gini';
  end else if aSplitCrit = scEntropy then begin
    Result := 'Entropy';
  end;
end;

function DistanceMethodToStr(Mode: TDistanceMode): string;
begin
  case Mode of
    dmManhattan: Result := 'Manhattan';
    dmEuclidean: Result := 'Euclidean';
    dmCosine: Result := 'Cosine';
    dmJaccard: Result := 'Jaccard';
    dmPearson: Result := 'Pearson';
  else
    Result := '';
  end;
end;

function AggregModeToStr(Method: TUserScoreAggregationMethod): string;
begin
  case Method of
    amMode: Result := 'Mode';
    amWeightedAverage: Result := 'Weighted Average';
    amSimpleSum: Result := 'Simple Sum';
  else
    Result := '';
  end;
end;


function PCThreadCount : Integer;
begin
  {$IFDEF FPC}
  Result := GetSystemThreadCount;
  {$ELSE}
  Result := TThread.ProcessorCount;
  {$ENDIF}
end;

procedure CleanObjectList(aList : TList<TObject>);
var
  i : Integer;
begin
  for i := 0 to aList.Count-1 do begin
    aList[i].Free;
  end;
  aList.Clear;
end;


end.
