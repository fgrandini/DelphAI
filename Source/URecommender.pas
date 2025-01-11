unit URecommender;

interface

uses
  System.SysUtils, Dialogs, UAITypes, System.Generics.Collections, UAIModel, Data.DB;

type
  TRecommender = class(TRecommendationModel)
  private
    FMatrixItem : TAIDatasetRecommendation;
    FClosestItems,
    FClosestUsers : TDictionary<Integer, TArray<Integer>>;
    FK : Integer;
    FItemsToRecommendCount: Integer;
    FAggregMethod : TUserScoreAggregationMethod;

    FDistanceMethod : TDistanceMode;

    FTrainingUser : Boolean;

    function getNumUsers : Integer;
    function getNumItems : Integer;

    function CalculateManhattanDistance(A, B: Integer; aIsUserBased: Boolean; aArrayA: TArray<Double> = nil; aArrayB: TArray<Double> = nil): Double;
    function CalculateEuclideanDistance(A, B: Integer; aIsUserBased: Boolean; aArrayA: TArray<Double> = nil; aArrayB: TArray<Double> = nil): Double;
    function CalculateCosineSimilarity(A, B: Integer; aIsUserBased: Boolean; aArrayA: TArray<Double> = nil; aArrayB: TArray<Double> = nil): Double;
    function CalculateJaccardDistance(A, B: Integer; aIsUserBased: Boolean; aArrayA: TArray<Double> = nil; aArrayB: TArray<Double> = nil): Double;
    function CalculatePearsonCorrelation(A, B: Integer; aIsUserBased: Boolean; aArrayA: TArray<Double> = nil; aArrayB: TArray<Double> = nil): Double;

    function GetMostCommonItems: TArray<Integer>;
    function GetRecommendedItems(const aRate: TAIDatasetRecommendation; aProximity, aConsumedItems: TArray<Double>;
                                 aTopN: Integer; aMethod: TUserScoreAggregationMethod): TArray<Integer>;
    function CalculateDistance(A, B: Integer; aIsUserBased: Boolean; aArrayA: TArray<Double> = nil; aArrayB: TArray<Double> = nil): Double;
    procedure DoCreate(aItemsToRecommendCount, aK : Integer;
                       aAggregMethod : TUserScoreAggregationMethod = amWeightedAverage; aDistanceMethod : TDistanceMode = dmCosine;
                       aCalculateItemDistanceOnCreate : Boolean = False);
    function InvertMatrix(const aDataset: TAIDatasetRecommendation): TAIDatasetRecommendation;
  public
    constructor Create(aMatrix: TAIDatasetRecommendation; aNormalizationRange : TNormalizationRange; aItemsToRecommendCount, aK : Integer;
                       aAggregMethod : TUserScoreAggregationMethod = amWeightedAverage; aDistanceMethod : TDistanceMode = dmCosine;
                       aCalculateItemDistanceOnCreate : Boolean = False); overload;
    constructor Create(aMatrixFile : String; aItemsToRecommendCount, aK : Integer;
                       aAggregMethod : TUserScoreAggregationMethod = amWeightedAverage; aDistanceMethod : TDistanceMode = dmCosine;
                       aCalculateItemDistanceOnCreate : Boolean = False; aHasHeader : Boolean = True); overload;
    constructor Create(aMatrix: TDataSet; aItemsToRecommendCount, aK : Integer;
                       aAggregMethod : TUserScoreAggregationMethod = amWeightedAverage; aDistanceMethod : TDistanceMode = dmCosine;
                       aCalculateItemDistanceOnCreate : Boolean = False); overload;

    destructor Destroy; override;

    function RecommendFromItem(aItemID: Integer): TArray<Integer>; overload;
    function RecommendFromItem(aItemInfo: TArray<Double>; aIDSearch : Integer = -1): TArray<Integer>; overload;
    function RecommendFromUser(aUserID: Integer): TArray<Integer>; overload;
    function RecommendFromUser(aUserInfo: TArray<Double>; aIDSearch : Integer = -1): TArray<Integer>; overload;
    procedure GenerateItemMatrix;

    procedure CalculateItemRecall(out aItemRecall: Double);
    procedure CalculateUserRecall(out aUserRecall: Double; aItemsToTest : TArray<TArray<Integer>>);

    property ItemsToRecommendCount    : Integer read FItemsToRecommendCount;
    property K              : Integer read FK;
    property AggregMethod   : TUserScoreAggregationMethod read FAggregMethod;
    property DistanceMethod : TDistanceMode read FDistanceMethod;
  end;


implementation

uses
  System.Generics.Defaults, System.Math, UAuxGlobal, UError;


{ TRecommender }

function TRecommender.InvertMatrix(const aDataset: TAIDatasetRecommendation): TAIDatasetRecommendation;
var
  i, j: Integer;
  vItemCount, vUserCount: Integer;
  vInvertedMatrix: TAIDatasetRecommendation;
begin
  vItemCount := 0;
  vUserCount := Length(aDataset);
  if vUserCount > 0 then
    vItemCount := Length(aDataset[0]);

  SetLength(vInvertedMatrix, vItemCount, vUserCount);

  for i := 0 to vUserCount - 1 do
    for j := 0 to vItemCount - 1 do
      vInvertedMatrix[j, i] := aDataset[i, j];

  Result := vInvertedMatrix;
end;

constructor TRecommender.Create(aMatrix: TAIDatasetRecommendation; aNormalizationRange : TNormalizationRange; aItemsToRecommendCount, aK : Integer;
                       aAggregMethod : TUserScoreAggregationMethod = amWeightedAverage; aDistanceMethod : TDistanceMode = dmCosine;
                       aCalculateItemDistanceOnCreate : Boolean = False);
begin
  FDataset := Copy(aMatrix);
  FNormalizationRange := aNormalizationRange;
  DoCreate(aItemsToRecommendCount, aK, aAggregMethod, aDistanceMethod, aCalculateItemDistanceOnCreate);
end;

constructor TRecommender.Create(aMatrixFile : String; aItemsToRecommendCount, aK : Integer;
                       aAggregMethod : TUserScoreAggregationMethod = amWeightedAverage; aDistanceMethod : TDistanceMode = dmCosine;
                       aCalculateItemDistanceOnCreate : Boolean = False; aHasHeader : Boolean = True);
begin
  LoadDataset(aMatrixFile, FDataset, FNormalizationRange, aHasHeader);
  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  DoCreate(aItemsToRecommendCount, aK, aAggregMethod, aDistanceMethod, aCalculateItemDistanceOnCreate);
end;

constructor TRecommender.Create(aMatrix: TDataSet; aItemsToRecommendCount, aK : Integer;
                       aAggregMethod : TUserScoreAggregationMethod = amWeightedAverage; aDistanceMethod : TDistanceMode = dmCosine;
                       aCalculateItemDistanceOnCreate : Boolean = False);
begin
  if aMatrix.RecordCount = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  LoadDataset(aMatrix, FDataset, FNormalizationRange);
  DoCreate(aItemsToRecommendCount, aK, aAggregMethod, aDistanceMethod, aCalculateItemDistanceOnCreate);
end;


procedure TRecommender.DoCreate(aItemsToRecommendCount, aK : Integer;
                       aAggregMethod : TUserScoreAggregationMethod = amWeightedAverage; aDistanceMethod : TDistanceMode = dmCosine;
                       aCalculateItemDistanceOnCreate : Boolean = False);
begin
  FTrainingUser := False;
  FItemsToRecommendCount := aItemsToRecommendCount;
  FAggregMethod := aAggregMethod;
  FK := aK;

  SetLength(FDataset, getNumUsers, getNumItems);

  if aCalculateItemDistanceOnCreate then begin
    GenerateItemMatrix;
  end;

  FDistanceMethod := aDistanceMethod;

  FClosestItems := TDictionary<Integer, TArray<Integer>>.Create;
  FClosestUsers := TDictionary<Integer, TArray<Integer>>.Create;
end;

function TRecommender.getNumUsers: Integer;
begin
  Result := Length(FDataset);
end;

function TRecommender.getNumItems: iNTEGER;
begin
  if getNumUsers > 0 then begin
    Result := Length(FDataset[0])
  end else begin
    Result := 0;
  end;
end;

procedure TRecommender.GenerateItemMatrix;
begin
  FMatrixItem := InvertMatrix(FDataset);
end;

destructor TRecommender.Destroy;
begin
  FClosestItems.Free;
  FClosestUsers.Free;
  inherited;
end;

function TRecommender.CalculateManhattanDistance(A, B: Integer; aIsUserBased: Boolean; aArrayA: TArray<Double> = nil; aArrayB: TArray<Double> = nil): Double;
var
  i: Integer;
  vDistance: Double;
  vUserA, vUserB: TArray<Double>;
  vUseful : Boolean;
begin
  vDistance := 0;

  if Length(aArrayA) > 0 then
    vUserA := aArrayA
  else if aIsUserBased then
    vUserA := FDataset[A]
  else
    vUserA := FMatrixItem[A];

  if Length(aArrayB) > 0 then
    vUserB := aArrayB
  else if aIsUserBased then
    vUserB := FDataset[B]
  else
    vUserB := FMatrixItem[B];

  vUseful := False;
  for i := 0 to High(vUserA) do begin
    if (not vUseful) and (vUserB[i] > 0) and (vUserA[i] = 0) then begin
      vUseful := True;
    end;
    vDistance := vDistance + Abs(vUserA[i] - vUserB[i]);
  end;

  if vUseful then begin
    Result := vDistance;
  end else begin
    Result := MaxDouble;
  end;
end;

function TRecommender.CalculateEuclideanDistance(A, B: Integer; aIsUserBased: Boolean; aArrayA: TArray<Double> = nil; aArrayB: TArray<Double> = nil): Double;
var
  i: Integer;
  vDistance: Double;
  vUserA, vUserB: TArray<Double>;
  vUseful : Boolean;
begin
  vDistance := 0;
  vUseful := False;

  if Length(aArrayA) > 0 then
    vUserA := aArrayA
  else if aIsUserBased then
    vUserA := FDataset[A]
  else
    vUserA := FMatrixItem[A];

  if Length(aArrayB) > 0 then
    vUserB := aArrayB
  else if aIsUserBased then
    vUserB := FDataset[B]
  else
    vUserB := FMatrixItem[B];

  for i := 0 to High(vUserA) do begin
    if (not vUseful) and (vUserB[i] > 0) and (vUserA[i] = 0) then begin
      vUseful := True;
    end;

    vDistance := vDistance + Sqr(Abs(vUserA[i] - vUserB[i]));
  end;

  if vUseful then begin
    Result := Sqrt(vDistance);
  end else begin
    Result := MaxDouble;
  end;

end;

function TRecommender.CalculateCosineSimilarity(A, B: Integer; aIsUserBased: Boolean; aArrayA: TArray<Double> = nil; aArrayB: TArray<Double> = nil): Double;
var
  i: Integer;
  vDotProduct, vMagnitudeA, vMagnitudeB: Double;
  vUserA, vUserB: TArray<Double>;
  vUseful : Boolean;
begin
  vUseful := False;
  vDotProduct := 0;
  vMagnitudeA := 0;
  vMagnitudeB := 0;

  if Length(aArrayA) > 0 then
    vUserA := aArrayA
  else if aIsUserBased then
    vUserA := FDataset[A]
  else
    vUserA := FMatrixItem[A];

  if Length(aArrayB) > 0 then
    vUserB := aArrayB
  else if aIsUserBased then
    vUserB := FDataset[B]
  else
    vUserB := FMatrixItem[B];

  for i := 0 to High(vUserA) do begin
    if (not vUseful) and (vUserB[i] > 0) and (vUserA[i] = 0) then begin
      vUseful := True;
    end;
    vDotProduct := vDotProduct + (vUserA[i] * vUserB[i]);
    vMagnitudeA := vMagnitudeA + Sqr(vUserA[i]);
    vMagnitudeB := vMagnitudeB + Sqr(vUserB[i]);
  end;

  if vUseful then begin
    Result := vDotProduct / (Sqrt(vMagnitudeA) * Sqrt(vMagnitudeB));
  end else begin
    Result := -MaxDouble;
  end;
end;

function TRecommender.CalculateJaccardDistance(A, B: Integer; aIsUserBased: Boolean; aArrayA: TArray<Double> = nil; aArrayB: TArray<Double> = nil): Double;
var
  i: Integer;
  vIntersection, vUnion: Double;
  vUserA, vUserB: TArray<Double>;
  vUseful : Boolean;
begin
  vIntersection := 0;
  vUnion := 0;
  vUseful := False;

  if Length(aArrayA) > 0 then
    vUserA := aArrayA
  else if aIsUserBased then
    vUserA := FDataset[A]
  else
    vUserA := FMatrixItem[A];

  if Length(aArrayB) > 0 then
    vUserB := aArrayB
  else if aIsUserBased then
    vUserB := FDataset[B]
  else
    vUserB := FMatrixItem[B];

  for i := 0 to High(vUserA) do begin
    if (not vUseful) and (vUserB[i] > 0) and (vUserA[i] = 0) then begin
      vUseful := True;
    end;
    if (vUserA[i] > 0) or (vUserB[i] > 0) then begin
      vUnion := vUnion + 1;
      if (vUserA[i] > 0) and (vUserB[i] > 0) then
        vIntersection := vIntersection + 1;
    end;
  end;

  if vUseful then begin
    if vUnion = 0 then
      Result := 1.0
    else
      Result := 1 - (vIntersection / vUnion);
  end else begin
    Result := MaxDouble;
  end;
end;

function TRecommender.CalculatePearsonCorrelation(A, B: Integer; aIsUserBased: Boolean; aArrayA: TArray<Double> = nil; aArrayB: TArray<Double> = nil): Double;
var
  i: Integer;
  vSumA, vSumB, vSumASq, vSumBSq, vSumAB, vMeanA, vMeanB: Double;
  N: Integer;
  vUserA, vUserB: TArray<Double>;
begin
  vSumA := 0;
  vSumB := 0;
  vSumASq := 0;
  vSumBSq := 0;
  vSumAB := 0;
  N := 0;

  if Length(aArrayA) > 0 then
    vUserA := aArrayA
  else if aIsUserBased then
    vUserA := FDataset[A]
  else
    vUserA := FMatrixItem[A];

  if Length(aArrayB) > 0 then
    vUserB := aArrayB
  else if aIsUserBased then
    vUserB := FDataset[B]
  else
    vUserB := FMatrixItem[B];

  if Length(vUserA) <> Length(vUserB) then
    raise Exception.Create('Vectors A and B have different sizes.');

  for i := 0 to High(vUserA) do
  begin
    if not IsNan(vUserA[i]) and not IsNan(vUserB[i]) then
    begin
      vSumA := vSumA + vUserA[i];
      vSumB := vSumB + vUserB[i];
      vSumASq := vSumASq + Sqr(vUserA[i]);
      vSumBSq := vSumBSq + Sqr(vUserB[i]);
      vSumAB := vSumAB + (vUserA[i] * vUserB[i]);
      Inc(N);
    end;
  end;

  if N = 0 then
  begin
    Result := 0;
    Exit;
  end;

  vMeanA := vSumA / N;
  vMeanB := vSumB / N;

  vSumASq := 0;
  vSumBSq := 0;
  vSumAB := 0;
  for i := 0 to High(vUserA) do
  begin
    if not IsNan(vUserA[i]) and not IsNan(vUserB[i]) then
    begin
      vSumASq := vSumASq + Sqr(vUserA[i] - vMeanA);
      vSumBSq := vSumBSq + Sqr(vUserB[i] - vMeanB);
      vSumAB := vSumAB + ((vUserA[i] - vMeanA) * (vUserB[i] - vMeanB));
    end;
  end;

  if (vSumASq = 0) or (vSumBSq = 0) then
  begin
    Result := 0;
    Exit;
  end;

  Result := vSumAB / Sqrt(vSumASq * vSumBSq);
end;

function TRecommender.CalculateDistance(A, B: Integer; aIsUserBased: Boolean; aArrayA: TArray<Double> = nil; aArrayB: TArray<Double> = nil): Double;
begin
  case FDistanceMethod of
    dmManhattan:
      Result := CalculateManhattanDistance(A, B, aIsUserBased, aArrayA, aArrayB);
    dmEuclidean:
      Result := CalculateEuclideanDistance(A, B, aIsUserBased, aArrayA, aArrayB);
    dmCosine:
      Result := CalculateCosineSimilarity(A, B, aIsUserBased, aArrayA, aArrayB);
    dmJaccard:
      Result := CalculateJaccardDistance(A, B, aIsUserBased, aArrayA, aArrayB);
    dmPearson:
      Result := CalculatePearsonCorrelation(A, B, aIsUserBased, aArrayA, aArrayB);
  else
    raise Exception.Create('Invalid distance mode');
  end;
  if IsNan(Result) then begin
    Result := 0;
  end;
end;

procedure TRecommender.CalculateUserRecall(out aUserRecall: Double; aItemsToTest : TArray<TArray<Integer>>);
var
  vBkpMatrix: TAIDatasetRecommendation;
  i, j, k : Integer;
  vNumUsers: Integer;
  vNumItems: Integer;
  vQtdTests,
  vUserHitCount, vTotalUserTests: Integer;
  vRecommendedItems: TArray<Integer>;
begin
  FTrainingUser := True;
  try
    SetLength(vBkpMatrix, Length(FDataset), Length(FDataset[0]));
    vNumItems := getNumItems;
    vNumUsers := getNumUsers;
    for i := 0 to getNumUsers - 1 do begin
      for j := 0 to vNumItems - 1 do begin
        vBkpMatrix[i][j] := FDataset[i][j];
      end;
    end;

    vUserHitCount := 0;
    vTotalUserTests := 0;

    if vNumUsers > 8000 then begin
      vQtdTests := 8000;
    end else begin
      vQtdTests := vNumUsers;
    end;

    for i := vNumUsers - vQtdTests to vNumUsers - 1 do begin
      for j in aItemsToTest[i] do begin
        FDataset[i][j] := 0;
        vRecommendedItems := RecommendFromUser(i);
        for k := 0 to High(vRecommendedItems) do begin
          if j = vRecommendedItems[k] then begin
            Inc(vUserHitCount);
            Break;
          end;
        end;

        FDataset[i][j] := vBkpMatrix[i][j];

        Inc(vTotalUserTests);
      end;
    end;

    if vTotalUserTests > 0 then begin
      aUserRecall := vUserHitCount / vTotalUserTests;
    end else begin
      aUserRecall := 0.0;
    end;
  finally
    FTrainingUser := False;
  end;
end;

procedure TRecommender.CalculateItemRecall(out aItemRecall: Double);
var
  vBkpMatrixItem: TAIDatasetRecommendation;
  i, j, k, l : Integer;
  vQtdTests,
  vItemHitCount, vTotalItemTests: Integer;
  vRecommendedItems: TArray<Integer>;
  vFound : Boolean;
begin
  vBkpMatrixItem := Copy(FMatrixItem);

  vItemHitCount := 0;
  vTotalItemTests := 0;

  if getNumUsers > 100000 then begin
    vQtdTests := 100000;
  end else begin
    vQtdTests := getNumUsers;
  end;

  for i := getNumUsers - vQtdTests to getNumUsers - 1 do begin
    for j := 0 to getNumItems - 1 do begin
      if FDataset[i][j] > 0 then begin
        vFound := False;
        for k := 0 to getNumItems - 1 do begin
          if (k <> j) and (FDataset[i][k] > 0) then begin
            vRecommendedItems := RecommendFromItem(k);
            for l := 0 to High(vRecommendedItems) do begin
              if j = vRecommendedItems[l] then begin
                Inc(vItemHitCount);
                vFound := True;
                Break;
              end;
            end;
            if vFound then begin
              Break;
            end;
          end;
        end;
        Inc(vTotalItemTests);
      end;
    end;
  end;
  if vTotalItemTests > 0 then
    aItemRecall := vItemHitCount / vTotalItemTests
  else
    aItemRecall := 0.0;
end;

function TRecommender.RecommendFromUser(aUserID: Integer): TArray<Integer>;
begin
  Result := RecommendFromUser(FDataset[aUserID], aUserID);
end;

function TRecommender.RecommendFromItem(aItemInfo: TArray<Double>; aIDSearch : Integer = -1): TArray<Integer>;
var
  vDistances: TArray<Double>;
  vBestItemIndexes: TArray<Integer>;
  i: Integer;
  vSaveValue: TArray<Integer>;
begin
  if Length(FMatrixItem) = 0 then begin
    GenerateItemMatrix;
  end;
  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;
  if Length(aItemInfo) <> Length(FDataset) then begin
    raise Exception.Create(ERROR_INPUT_SIZE_DIFFERENT);
  end;

  if (not FTrainingUser) and (aIDSearch <> -1) and FClosestItems.TryGetValue(aIDSearch, vSaveValue) then begin
    Exit(Copy(vSaveValue));
  end;
  SetLength(vDistances, getNumItems);
  SetLength(vBestItemIndexes, getNumItems);
  SetLength(Result, ItemsToRecommendCount);

  for i := 0 to getNumItems - 1 do begin
    if i = aIDSearch then begin
      if FDistanceMethod in [dmCosine, dmPearson] then begin
        vDistances[i] := -MaxDouble;
      end else begin
        vDistances[i] := MaxDouble;
      end;
    end else begin
      vDistances[i] := CalculateDistance(0, i, False, aItemInfo);
    end;
    vBestItemIndexes[i] := i;
  end;

  if FDistanceMethod in [dmCosine, dmPearson] then begin
    TArray.Sort<Integer>(vBestItemIndexes,
      TComparer<Integer>.Construct(
        function(const Left, Right: Integer): Integer
        begin
          Result := CompareValue(vDistances[Right], vDistances[Left]);
        end
      )
    );
  end else begin
    TArray.Sort<Integer>(vBestItemIndexes,
      TComparer<Integer>.Construct(
        function(const Left, Right: Integer): Integer
        begin
          Result := CompareValue(vDistances[Left], vDistances[Right]);
        end
      )
    );
  end;

  SetLength(vBestItemIndexes, ItemsToRecommendCount);

  Result := vBestItemIndexes;

  if (not FTrainingUser) and (aIDSearch <> -1) then begin
    FClosestItems.Add(aIDSearch, Copy(Result));
  end;
end;

function TRecommender.RecommendFromItem(aItemID: Integer): TArray<Integer>;
begin
  if Length(FMatrixItem) = 0 then begin
    GenerateItemMatrix;
  end;
  SetLength(Result, ItemsToRecommendCount);
  Result := RecommendFromItem(FMatrixItem[aItemID], aItemID);
end;

function TRecommender.RecommendFromUser(aUserInfo: TArray<Double>; aIDSearch : Integer = -1) : TArray<Integer>;
var
  vDistances, vOta: TArray<Double>;
  vBestUserIndexes: TArray<Integer>;
  vRatesRec: TAIDatasetRecommendation;
  vFilteredDistances: TArray<Double>;
  i: Integer;
  vSaveValue: TArray<Integer>;
begin
  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;

  if Length(aUserInfo) <> Length(FDataset[0]) then begin
    raise Exception.Create(ERROR_INPUT_SIZE_DIFFERENT);
  end;

  if (not FTrainingUser) and (aIDSearch <> -1) and FClosestUsers.TryGetValue(aIDSearch, vSaveValue) then begin
    Exit(vSaveValue);
  end;

  SetLength(vDistances, getNumUsers);
  SetLength(vBestUserIndexes, getNumUsers);
  SetLength(vFilteredDistances, FK);
  SetLength(vRatesRec, FK, getNumItems);

  for i := 0 to getNumUsers - 1 do begin
    if i = aIDSearch then begin
      if FDistanceMethod in [dmCosine, dmPearson] then begin
        vDistances[i] := -MaxDouble;
      end else begin
        vDistances[i] := MaxDouble;
      end;
    end else begin
      vDistances[i] := CalculateDistance(0, i, True, aUserInfo);
    end;
    vBestUserIndexes[i] := i;
  end;
  vOta := vDistances;

  if FDistanceMethod in [dmCosine, dmPearson] then begin
    TArray.Sort<Integer>(vBestUserIndexes,
      TComparer<Integer>.Construct(
        function(const Left, Right: Integer): Integer
        begin
          Result := CompareValue(vDistances[Right], vDistances[Left]);
        end
      )
    );
  end else begin
    TArray.Sort<Integer>(vBestUserIndexes,
      TComparer<Integer>.Construct(
        function(const Left, Right: Integer): Integer
        begin
          Result := CompareValue(vDistances[Left], vDistances[Right]);
        end
      )
    );
  end;

  SetLength(vBestUserIndexes, FK);

  for i := 0 to FK - 1 do begin
    vRatesRec[i] := FDataset[vBestUserIndexes[i]];
    vFilteredDistances[i] := vDistances[vBestUserIndexes[i]];
  end;

  Result := GetRecommendedItems(vRatesRec, vFilteredDistances, aUserInfo, FItemsToRecommendCount, FAggregMethod);

  if Length(Result) = 0 then begin
    Result := GetMostCommonItems;
  end;

  if (not FTrainingUser) and (aIDSearch <> -1) then begin
    FClosestUsers.Add(aIDSearch, Result);
  end;
end;

function TRecommender.GetMostCommonItems: TArray<Integer>;
var
  vItemFrequency: TDictionary<Integer, Integer>;
  vItem, vCount, i: Integer;
  vSortedItems: TArray<Integer>;
begin
  vItemFrequency := TDictionary<Integer, Integer>.Create;
  try
    for i := 0 to getNumUsers - 1 do
    begin
      for vItem := 0 to getNumItems - 1 do
      begin
        if FDataset[i][vItem] > 0 then
        begin
          if not vItemFrequency.TryGetValue(vItem, vCount) then
            vCount := 0;
          vItemFrequency[vItem] := vCount + 1;
        end;
      end;
    end;

    vSortedItems := vItemFrequency.Keys.ToArray;
    TArray.Sort<Integer>(vSortedItems, TComparer<Integer>.Construct(
      function(const Left, Right: Integer): Integer
      begin
        Result := vItemFrequency[Right] - vItemFrequency[Left];
      end
    ));

    SetLength(Result, Min(FItemsToRecommendCount, Length(vSortedItems)));
    for i := 0 to High(Result) do
      Result[i] := vSortedItems[i];
  finally
    vItemFrequency.Free;
  end;
end;

function TRecommender.GetRecommendedItems(const aRate: TAIDatasetRecommendation; aProximity, aConsumedItems: TArray<Double>; aTopN: Integer; aMethod: TUserScoreAggregationMethod): TArray<Integer>;
var
  i, j: Integer;
  vItemScores: TArray<Double>;
  vRankedItems: TArray<Integer>;
begin
  SetLength(vItemScores, getNumItems);
  for i := 0 to getNumItems - 1 do
    vItemScores[i] := 0.0;

  for i := 0 to Length(aProximity) - 1 do begin

    if aProximity[i] = 0 then
      Continue;

    for j := 0 to getNumItems - 1 do begin
      if (aConsumedItems[j] <= 0) and (aRate[i][j] > 0) then begin
        case aMethod of
          amMode:
            vItemScores[j] := vItemScores[j] + 1;
          amWeightedAverage:
            vItemScores[j] := vItemScores[j] + (aRate[i][j] * aProximity[i]);
          amSimpleSum:
            vItemScores[j] := vItemScores[j] + aRate[i][j];
        end;
      end;
    end;
  end;

  SetLength(vRankedItems, getNumItems);
  for i := 0 to getNumItems - 1 do
    vRankedItems[i] := i;

  TArray.Sort<Integer>(vRankedItems, TComparer<Integer>.Construct(
    function(const Left, Right: Integer): Integer
    begin
      if vItemScores[Left] > vItemScores[Right] then
        Result := -1
      else if vItemScores[Left] < vItemScores[Right] then
        Result := 1
      else
        Result := 0;
    end));

  SetLength(Result, aTopN);
  for i := 0 to aTopN - 1 do
    Result[i] := vRankedItems[i];
end;


end.

