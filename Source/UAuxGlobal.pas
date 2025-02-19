unit UAuxGlobal;

interface

uses
  UKNN,
  UAISelector,
  Data.DB,
  UAITypes,
  System.Generics.Collections;

type

  TAIDatasetGeneric = TArray<TAISampleClassification>;

  function CalculateEuclideanDistance(const aPointA, aPointB: TAISampleAtr): Double;
  function SplitLabelAndSampleDataset(const ADataset: TAIDatasetClassification; out ASamples: TAISamplesAtr; out ALabels: TAILabelsClassification): Boolean; overload;
  function SplitLabelAndSampleDataset(const ADataset: TAIDatasetRegression; out ASamples: TAISamplesAtr; out ALabels: TAILabelsRegression): Boolean; overload;

  function LoadDataset(const aFileName: String; out aData: TAIDatasetRegression; out aNormalizationRange : TNormalizationRange; aHasHeader : Boolean = True): Boolean; overload;
  function LoadDataset(const aFileName: String; out aData: TAIDatasetClassification; out aNormalizationRange : TNormalizationRange; aHasHeader : Boolean = True): Boolean; overload;
  function LoadDataset(const aFileName: String; out aData: TArray<TAISampleAtr>; out aNormalizationRange : TNormalizationRange; aHasHeader: Boolean = True): Boolean; overload;

  function LoadDataset(const aDataSet : TDataSet; out aData: TAIDatasetRegression; out aNormalizationRange : TNormalizationRange): Boolean; overload;
  function LoadDataset(const aDataSet : TDataSet; out aData: TAIDatasetClassification; out aNormalizationRange : TNormalizationRange): Boolean; overload;
  function LoadDataset(const aDataSet : TDataSet; out aData: TArray<TAISampleAtr>; out aNormalizationRange : TNormalizationRange): Boolean; overload;

  function LoadGenericDataSetFile(const aFileName: String; out aData: TAIDatasetGeneric; aHasHeader : Boolean = True; aClassification : Boolean = False) : Boolean;
  function LoadGenericDataSetQuery(const aDataSet : TDataSet; out aData: TAIDatasetGeneric; aClassification : Boolean = False) : Boolean;

  function IndexOfMax(const values: TArray<Double>): Integer; overload;
  function IndexOfMax(const values: array of Single): Integer; overload;

  function GetRandomValues(const aLimit, X: Integer): TDictionary<Integer, Boolean>;

  procedure NormalizeSamples(var aData: TAISamplesAtr; const aNormRange: TNormalizationRange);
  function NormalizeDataset(var aData: TAIDatasetRegression) : TNormalizationRange; overload;
  function NormalizeDataset(var aData: TAIDatasetClassification) : TNormalizationRange; overload;
  function NormalizeDataset(var aData: TArray<TAISampleAtr>) : TNormalizationRange; overload;

  function SplitCriterionToString(aSplitCrit : TSplitCriterion) : String;
  function DistanceMethodToStr(Mode: TDistanceMode): string;
  function AggregModeToStr(Method: TUserScoreAggregationMethod): string;

  function PCThreadCount : Integer;
  procedure CleanObjectList(aList : TList<TObject>);

  function CalculateMinAndMax(const aData: TAISamplesAtr): TNormalizationRange;
  function Distance(const A, B: TAISampleAtr): Double;

implementation

uses
  System.SysUtils,
  Graphics,
  Winapi.Windows,
  System.Classes,
  System.Math,
  System.StrUtils;

function CalculateEuclideanDistance(const aPointA, aPointB: TAISampleAtr): Double;
var
  i: Integer;
  vSum: Double;
begin
  vSum := 0.0;
  for i := 0 to Length(aPointA) - 1 do begin
    vSum := vSum + Sqr(aPointA[i] - aPointB[i]);
  end;
  Result := Sqrt(vSum);
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

function LoadGenericDataSetQuery(const aDataSet : TDataSet; out aData: TAIDatasetGeneric; aClassification : Boolean = False) : Boolean;
 var
  vClass: string;
  vPoint: TAISampleAtr;
  vRecordCount,
  i, j : Integer;

  procedure GeneratesErrorMessage(aMsgExtra : String; aLine, aColumn : Integer);
  begin
    raise Exception.Create('Error reading Dataset.' +
                           ' Line: ' + IntToStr(aLine + 1) + ', Column ' + IntToStr(aColumn + 1) + '. ' +
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

  SetLength(aData, vRecordCount);
  aDataSet.First;
  for i := 0 to Length(aData) - 1 do begin
    SetLength(vPoint, aDataSet.FieldCount - 1);
    for j := 0 to Length(vPoint) - 1 do begin
      try
        vPoint[j] := aDataSet.FieldByName(aDataSet.Fields[j].FieldName).AsCurrency;
      except
        on E:EConvertError do begin
          GeneratesErrorMessage('Please verify if all columns' + IfThen(aClassification, ' (except the last one)', '') +
                                ' contain only float values. Error: ' + E.Message, i, j);
        end;
        on E:Exception do begin
          GeneratesErrorMessage('Error: ' + E.Message, i, j);
        end;
      end;
    end;
    try
      vClass := aDataSet.FieldByName(aDataSet.Fields[aDataSet.FieldCount - 1].FieldName).AsString;
      if not aClassification then begin
        StrToFloat(StringReplace(vClass, ',', '.', [rfReplaceAll]), TFormatSettings.Create('en-US'));
      end;
    except
        on E:EConvertError do begin
          GeneratesErrorMessage('Please verify if all columns' + IfThen(aClassification, ' (except the last one)', '') +
                                ' contain only float values. Error: ' + E.Message, i, aDataSet.FieldCount - 1);
        end;
        on E:Exception do begin
          GeneratesErrorMessage('Error: ' + E.Message, i, aDataSet.FieldCount - 1);
        end;
    end;
    aData[i] := TAISampleClassification.Create(vPoint, vClass);
    aDataSet.Next;
  end;
  Result := True;
end;

function LoadGenericDataSetFile(const aFileName: String; out aData: TAIDatasetGeneric; aHasHeader : Boolean = True; aClassification : Boolean = False) : Boolean;
 var
  vList: TStringList;
  vLine,
  vClass: string;
  vFields: TAILabelsClassification;
  vPoint: TAISampleAtr;
  vBegin, i, j : Integer;

  procedure GeneratesErrorMessage(aMsgExtra : String; aLine, aColumn : Integer);
  begin
    raise Exception.Create('Error reading Dataset.' +
                           ' Line: ' + IntToStr(aLine + 1) + ', Column ' + IntToStr(aColumn + 1) + '. ' +
                           aMsgExtra);
  end;

begin
  vList := TStringList.Create;
  try
    vList.LoadFromFile(aFileName);
    if aHasHeader then begin
      vBegin := 1;
    end else begin
      vBegin := 0;
    end;
    i := vBegin;
    while i < vList.Count do begin
      vLine := vList[i];
      if Trim(vLine) = '' then begin
        vList.Delete(i);
      end else begin
        inc(i);
      end;
    end;
    SetLength(aData, vList.Count - vBegin);
    for i := vBegin to vList.Count - 1 do begin
      vLine := vList[i];

      vFields := vLine.Split([',']);
      SetLength(vPoint, Length(vFields) - 1);
      for j := 0 to Length(vPoint) - 1 do begin
        try
          vPoint[j] := StrToFloat(StringReplace(vFields[j], ',', '.', [rfReplaceAll]), TFormatSettings.Create('en-US'));
        except
          on E:EConvertError do begin
            GeneratesErrorMessage('Please verify if all columns' + IfThen(aClassification, ' (except the last one)', '') +
                                  ' contain only float values. Error: ' + E.Message, i, j);
          end;
          on E:Exception do begin
            GeneratesErrorMessage('Error: ' + E.Message, i, j);
          end;
        end;
      end;
      try
        vClass := vFields[Length(vFields) - 1];
        if not aClassification then begin
          StrToFloat(StringReplace(vClass, ',', '.', [rfReplaceAll]), TFormatSettings.Create('en-US'));
        end;
      except
        on E:EConvertError do begin
          GeneratesErrorMessage('Please verify if all columns' + IfThen(aClassification, ' (except the last one)', '') +
                                ' contain only float values. Error: ' + E.Message, i, Length(vFields) - 1);
        end;
        on E:Exception do begin
          GeneratesErrorMessage('Error: ' + E.Message, i, Length(vFields) - 1);
        end;
      end;
      aData[i - vBegin] := TAISampleClassification.Create(vPoint, vClass);
    end;
    Result := True;
  finally
    vList.Free;
  end;
end;

function LoadDataset(const aFileName: String; out aData: TAIDatasetClassification; out aNormalizationRange : TNormalizationRange; aHasHeader : Boolean = True): Boolean;
var
  vDataGeneric : TAIDatasetGeneric;
begin
  Result := LoadGenericDataSetFile(aFileName, vDataGeneric, aHasHeader, True);
  if Result then begin
    aData := vDataGeneric;
    aNormalizationRange := NormalizeDataset(aData);
  end;
end;

function LoadDataset(const aFileName: String; out aData: TAIDatasetRegression; out aNormalizationRange : TNormalizationRange; aHasHeader : Boolean = True): Boolean;
var
  vDataGeneric : TAIDatasetGeneric;
  i : Integer;
begin
  Result := LoadGenericDataSetFile(aFileName, vDataGeneric, aHasHeader);
   if Result then begin
    SetLength(aData, Length(vDataGeneric));
    for i := 0 to High(vDataGeneric) do begin
      aData[i] := TPair<TAISampleAtr, Double>.Create(vDataGeneric[i].Key, StrToCurr(StringReplace(vDataGeneric[i].Value, ',', '.', []), TFormatSettings.Create('en-US')));
    end;
    aNormalizationRange := NormalizeDataset(aData);
  end;
end;

function LoadDataset(const aFileName: String; out aData: TArray<TAISampleAtr>; out aNormalizationRange : TNormalizationRange; aHasHeader: Boolean = True): Boolean;
var
  vDataGeneric : TAIDatasetGeneric;
  i : Integer;
begin
  Result := LoadGenericDataSetFile(aFileName, vDataGeneric, aHasHeader);
  Result := Result and (Length(vDataGeneric) > 0);
  if Result then begin
    SetLength(aData, Length(vDataGeneric), Length(vDataGeneric[0].Key) + 1);
    for i := 0 to High(vDataGeneric) do begin
      aData[i] := vDataGeneric[i].Key;
      SetLength(aData[i], Length(aData[i]) + 1);
      aData[i][High(aData[i])] := StrToCurr(StringReplace(vDataGeneric[i].Value, ',', '.', []), TFormatSettings.Create('en-US'));
    end;
    aNormalizationRange := NormalizeDataset(aData);
  end;
end;

function IndexOfMax(const values: TArray<Double>): Integer;
var
  i, vMaxIndex: Integer;
  vMaxValue: Double;
begin
  if Length(values) = 0 then begin
    raise Exception.Create('Array empty.');
  end;

  vMaxIndex := 0;
  vMaxValue := values[0];

  for i := 1 to High(values) do begin
    if values[i] > vMaxValue then begin
      vMaxValue := values[i];
      vMaxIndex := i;
    end;
  end;

  Result := vMaxIndex;
end;

function IndexOfMax(const values: array of Single): Integer;
var
  i, vMaxIndex: Integer;
  vMaxValue: Double;
begin
  if Length(values) = 0 then begin
    raise Exception.Create('Array empty.');
  end;

  vMaxIndex := 0;
  vMaxValue := values[0];

  for i := 1 to High(values) do begin
    if values[i] > vMaxValue then begin
      vMaxValue := values[i];
      vMaxIndex := i;
    end;
  end;

  Result := vMaxIndex;
end;

function LoadDataset(const aDataset: TDataset; out aData: TAIDatasetClassification; out aNormalizationRange : TNormalizationRange): Boolean;
var
  vDataGeneric : TAIDatasetGeneric;
begin
  Result := LoadGenericDataSetQuery(aDataset, vDataGeneric, True);
   if Result then begin
    aData := vDataGeneric;
    aNormalizationRange := NormalizeDataset(aData);
  end;
end;

function LoadDataset(const aDataset: TDataset; out aData: TAIDatasetRegression; out aNormalizationRange : TNormalizationRange): Boolean;
var
  vDataGeneric : TAIDatasetGeneric;
  i : Integer;
begin
  Result := LoadGenericDataSetQuery(aDataset, vDataGeneric);
  if Result then begin
    SetLength(aData, Length(vDataGeneric));
    for i := 0 to High(vDataGeneric) do begin
      aData[i] := TPair<TAISampleAtr, Double>.Create(vDataGeneric[i].Key, StrToCurr(StringReplace(vDataGeneric[i].Value, ',', '.', []), TFormatSettings.Create('en-US')));
    end;
    aNormalizationRange := NormalizeDataset(aData);
  end;
end;

function LoadDataset(const aDataset: TDataset; out aData: TArray<TAISampleAtr>; out aNormalizationRange : TNormalizationRange): Boolean;
var
  vDataGeneric : TAIDatasetGeneric;
  i : Integer;
begin
  Result := LoadGenericDataSetQuery(aDataset, vDataGeneric);
  if Result then begin
    SetLength(aData, Length(vDataGeneric), Length(vDataGeneric[0].Key) + 1);
    for i := 0 to High(vDataGeneric) do begin
      aData[i] := vDataGeneric[i].Key;
      aData[i][High(aData[i])] := StrToCurr(StringReplace(vDataGeneric[i].Value, ',', '.', []), TFormatSettings.Create('en-US'));
    end;
    aNormalizationRange := NormalizeDataset(aData);
  end;
end;

function GetRandomValues(const aLimit, X: Integer): TDictionary<Integer, Boolean>;
var
  vNum: Integer;
begin
  if X > aLimit + 1 then begin
    raise Exception.Create('It is not possible to generate so many unique numbers within the specified limit.');
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

function CalculateMinAndMax(const aData: TAISamplesAtr): TNormalizationRange;
var
  vSampleCount, i, j: Integer;
begin
  vSampleCount := Length(aData);

  if vSampleCount = 0 then
    Exit;

  SetLength(Result.MinValues, Length(aData[0]));
  SetLength(Result.MaxValues, Length(aData[0]));

  for j := 0 to High(aData[0]) do
  begin
    Result.MinValues[j] := aData[0][j];
    Result.MaxValues[j] := aData[0][j];
  end;

  for i := 1 to vSampleCount - 1 do
    for j := 0 to High(aData[i]) do
    begin
      Result.MinValues[j] := Min(Result.MinValues[j], aData[i][j]);
      Result.MaxValues[j] := Max(Result.MaxValues[j], aData[i][j]);
    end;
end;

procedure NormalizeSamples(var aData: TAISamplesAtr; const aNormRange: TNormalizationRange);
var
  i, j: Integer;
begin
  for i := 0 to High(aData) do begin
    for j := 0 to High(aData[i]) do begin
      if (aNormRange.MaxValues[j] - aNormRange.MinValues[j]) <> 0 then begin
        aData[i][j] := (aData[i][j] - aNormRange.MinValues[j]) / (aNormRange.MaxValues[j] - aNormRange.MinValues[j])
      end else begin
        aData[i][j] := 0;
      end;
    end;
  end;
end;

function NormalizeDataset(var aData: TArray<TAISampleAtr>) : TNormalizationRange;
begin
  Result := CalculateMinAndMax(aData);
  NormalizeSamples(aData, Result);
end;

function NormalizeDataset(var aData: TAIDatasetRegression) : TNormalizationRange;
var
  vSamples: TAISamplesAtr;
  i: Integer;
begin
  SetLength(vSamples, Length(aData));
  for i := 0 to High(aData) do begin
    vSamples[i] := aData[i].Key;
  end;

  Result := CalculateMinAndMax(vSamples);
  NormalizeSamples(vSamples, Result);

  for i := 0 to High(aData) do begin
    aData[i] := TPair<TAISampleAtr, Double>.Create(vSamples[i], aData[i].Value);
  end;
end;

function NormalizeDataset(var aData: TAIDatasetClassification) : TNormalizationRange;
var
  vSamples: TAISamplesAtr;
  i: Integer;
begin
  SetLength(vSamples, Length(aData));
  for i := 0 to High(aData) do begin
    vSamples[i] := aData[i].Key;
  end;

  Result := CalculateMinAndMax(vSamples);
  NormalizeSamples(vSamples, Result);

  for i := 0 to High(aData) do begin
    aData[i] := TPair<TAISampleAtr, String>.Create(vSamples[i], aData[i].Value);
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

function Distance(const A, B: TAISampleAtr): Double;
var
  i: Integer;
  vSum: Double;
begin
  vSum := 0.0;
  for i := Low(A) to High(A) do
    vSum := vSum + Sqr(A[i] - B[i]);
  Result := Sqrt(vSum);
end;

end.
