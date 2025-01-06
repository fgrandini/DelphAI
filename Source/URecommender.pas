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
    function getNumItems : iNTEGER;

    function CalculateManhattanDistance(A, B: Integer; IsUserBased: Boolean; ArrayA: TArray<Double> = nil; ArrayB: TArray<Double> = nil): Double;
    function CalculateEuclideanDistance(A, B: Integer; IsUserBased: Boolean; ArrayA: TArray<Double> = nil; ArrayB: TArray<Double> = nil): Double;
    function CalculateCosineSimilarity(A, B: Integer; IsUserBased: Boolean; ArrayA: TArray<Double> = nil; ArrayB: TArray<Double> = nil): Double;
    function CalculateJaccardDistance(A, B: Integer; IsUserBased: Boolean; ArrayA: TArray<Double> = nil; ArrayB: TArray<Double> = nil): Double;
    function CalculatePearsonCorrelation(A, B: Integer; IsUserBased: Boolean; ArrayA: TArray<Double> = nil; ArrayB: TArray<Double> = nil): Double;

    function GetMostCommonItems: TArray<Integer>;
    function GetRecommendedItems(const aRate: TAIDatasetRecommendation; aProximity, aConsumedItems: TArray<Double>;
                                 aTopN: Integer; Method: TUserScoreAggregationMethod): TArray<Integer>;
    function CalculateDistance(A, B: Integer; IsUserBased: Boolean; ArrayA: TArray<Double> = nil; ArrayB: TArray<Double> = nil): Double;
    procedure DoCreate(aItemsToRecommendCount, aK : Integer;
                       aAggregMethod : TUserScoreAggregationMethod = amWeightedAverage; aDistanceMethod : TDistanceMode = dmCosine;
                       aCalculateItemDistanceOnCreate : Boolean = False);
  public
    constructor Create(aMatrix: TAIDatasetRecommendation; aNormalizationRange : TNormalizationRange; aItemsToRecommendCount, aK : Integer;
                       aAggregMethod : TUserScoreAggregationMethod = amWeightedAverage; aDistanceMethod : TDistanceMode = dmCosine;
                       aCalculateItemDistanceOnCreate : Boolean = False); overload;
    constructor Create(aMatrixFile : String; aItemsToRecommendCount, aK : Integer;
                       aAggregMethod : TUserScoreAggregationMethod = amWeightedAverage; aDistanceMethod : TDistanceMode = dmCosine;
                       aCalculateItemDistanceOnCreate : Boolean = False; aHaveHeader : Boolean = True); overload;
    constructor Create(aMatrix: TDataSet; aItemsToRecommendCount, aK : Integer;
                       aAggregMethod : TUserScoreAggregationMethod = amWeightedAverage; aDistanceMethod : TDistanceMode = dmCosine;
                       aCalculateItemDistanceOnCreate : Boolean = False); overload;

    destructor Destroy; override;

    function RecommendFromItem(aItemID: Integer): TArray<Integer>; overload;
    function RecommendFromItem(aItemInfo: TArray<Double>; aIDSearch : Integer = -1): TArray<Integer>; overload;
    function RecommendFromUser(aUserID: Integer): TArray<Integer>; overload;
    function RecommendFromUser(aUserInfo: TArray<Double>; aIDSearch : Integer = -1): TArray<Integer>; overload;
    procedure GenerateItemMatrix;

    procedure CalculateItemRecall(out ItemRecall: Double);
    procedure CalculateUserRecall(out UserRecall: Double; aItemsToTest : TArray<TArray<Integer>>);

    property ItemsToRecommendCount    : Integer read FItemsToRecommendCount;
    property K              : Integer read FK;
    property AggregMethod   : TUserScoreAggregationMethod read FAggregMethod;
    property DistanceMethod : TDistanceMode read FDistanceMethod;
  end;


implementation

uses
  System.Generics.Defaults, System.Math, UAuxGlobal, UError;


{ TRecommender }

function InvertMatrix(const aDataset: TAIDatasetRecommendation): TAIDatasetRecommendation;
var
  i, j: Integer;
  itemCount, userCount: Integer;
  InvertedMatrix: TAIDatasetRecommendation;
begin
  itemCount := 0;
  userCount := Length(aDataset);       
  if userCount > 0 then
    itemCount := Length(aDataset[0]);  

  SetLength(InvertedMatrix, itemCount, userCount);

  for i := 0 to userCount - 1 do
    for j := 0 to itemCount - 1 do
      InvertedMatrix[j, i] := aDataset[i, j];

  Result := InvertedMatrix;
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
                       aCalculateItemDistanceOnCreate : Boolean = False; aHaveHeader : Boolean = True);
begin
  LoadDataset(aMatrixFile, FDataset, FNormalizationRange, aHaveHeader);
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

function TRecommender.CalculateManhattanDistance(A, B: Integer; IsUserBased: Boolean; ArrayA: TArray<Double> = nil; ArrayB: TArray<Double> = nil): Double;
var
  i: Integer;
  Distance: Double;
  UserA, UserB: TArray<Double>;
  vUtil : Boolean;
begin
  Distance := 0;

  if Length(ArrayA) > 0 then
    UserA := ArrayA
  else if IsUserBased then
    UserA := FDataset[A]
  else
    UserA := FMatrixItem[A];

  if Length(ArrayB) > 0 then
    UserB := ArrayB
  else if IsUserBased then
    UserB := FDataset[B]
  else
    UserB := FMatrixItem[B];

  vUtil := False;
  for i := 0 to High(UserA) do begin
    if (not vUtil) and (UserB[i] > 0) and (UserA[i] = 0) then begin
      vUtil := True;
    end;
    Distance := Distance + Abs(UserA[i] - UserB[i]);
  end;

  if vUtil then begin
    Result := Distance;
  end else begin
    Result := MaxDouble;
  end;
end;

function TRecommender.CalculateEuclideanDistance(A, B: Integer; IsUserBased: Boolean; ArrayA: TArray<Double> = nil; ArrayB: TArray<Double> = nil): Double;
var
  i: Integer;
  Distance: Double;
  UserA, UserB: TArray<Double>;
  vUtil : Boolean;
begin
  Distance := 0;
  vUtil := False;

  if Length(ArrayA) > 0 then
    UserA := ArrayA
  else if IsUserBased then
    UserA := FDataset[A]
  else
    UserA := FMatrixItem[A];

  if Length(ArrayB) > 0 then
    UserB := ArrayB
  else if IsUserBased then
    UserB := FDataset[B]
  else
    UserB := FMatrixItem[B];

  for i := 0 to High(UserA) do begin
    if (not vUtil) and (UserB[i] > 0) and (UserA[i] = 0) then begin
      vUtil := True;
    end;

    Distance := Distance + Sqr(Abs(UserA[i] - UserB[i]));
  end;

  if vUtil then begin
    Result := Sqrt(Distance);
  end else begin
    Result := MaxDouble;
  end;

end;

function TRecommender.CalculateCosineSimilarity(A, B: Integer; IsUserBased: Boolean; ArrayA: TArray<Double> = nil; ArrayB: TArray<Double> = nil): Double;
var
  i: Integer;
  DotProduct, MagnitudeA, MagnitudeB: Double;
  UserA, UserB: TArray<Double>;
  vUtil : Boolean;
begin
  vUtil := False;
  DotProduct := 0;
  MagnitudeA := 0;
  MagnitudeB := 0;

  if Length(ArrayA) > 0 then
    UserA := ArrayA
  else if IsUserBased then
    UserA := FDataset[A]
  else
    UserA := FMatrixItem[A];

  if Length(ArrayB) > 0 then
    UserB := ArrayB
  else if IsUserBased then
    UserB := FDataset[B]
  else
    UserB := FMatrixItem[B];

  for i := 0 to High(UserA) do begin
    if (not vUtil) and (UserB[i] > 0) and (UserA[i] = 0) then begin
      vUtil := True;
    end;
    DotProduct := DotProduct + (UserA[i] * UserB[i]);
    MagnitudeA := MagnitudeA + Sqr(UserA[i]);
    MagnitudeB := MagnitudeB + Sqr(UserB[i]);
  end;

  if vUtil then begin
    Result := DotProduct / (Sqrt(MagnitudeA) * Sqrt(MagnitudeB));
  end else begin
    Result := -MaxDouble;
  end;
end;

function TRecommender.CalculateJaccardDistance(A, B: Integer; IsUserBased: Boolean; ArrayA: TArray<Double> = nil; ArrayB: TArray<Double> = nil): Double;
var
  i: Integer;
  Intersection, Union: Double;
  UserA, UserB: TArray<Double>;
  vUtil : Boolean;
begin
  Intersection := 0;
  Union := 0;
  vUtil := False;

  if Length(ArrayA) > 0 then
    UserA := ArrayA
  else if IsUserBased then
    UserA := FDataset[A]
  else
    UserA := FMatrixItem[A];

  if Length(ArrayB) > 0 then
    UserB := ArrayB
  else if IsUserBased then
    UserB := FDataset[B]
  else
    UserB := FMatrixItem[B];

  for i := 0 to High(UserA) do begin
    if (not vUtil) and (UserB[i] > 0) and (UserA[i] = 0) then begin
      vUtil := True;
    end;
    if (UserA[i] > 0) or (UserB[i] > 0) then begin
      Union := Union + 1;
      if (UserA[i] > 0) and (UserB[i] > 0) then
        Intersection := Intersection + 1;
    end;
  end;


  if vUtil then begin
    if Union = 0 then
      Result := 1.0
    else
      Result := 1 - (Intersection / Union);
  end else begin
    Result := MaxDouble;
  end;
end;

function TRecommender.CalculatePearsonCorrelation(A, B: Integer; IsUserBased: Boolean; ArrayA: TArray<Double> = nil; ArrayB: TArray<Double> = nil): Double;
var
  i: Integer;
  SumA, SumB, SumASq, SumBSq, SumAB, MeanA, MeanB: Double;
  N: Integer;
  UserA, UserB: TArray<Double>;
begin
  SumA := 0;
  SumB := 0;
  SumASq := 0;
  SumBSq := 0;
  SumAB := 0;
  N := 0;

  if Length(ArrayA) > 0 then
    UserA := ArrayA
  else if IsUserBased then
    UserA := FDataset[A]
  else
    UserA := FMatrixItem[A];

  if Length(ArrayB) > 0 then
    UserB := ArrayB
  else if IsUserBased then
    UserB := FDataset[B]
  else
    UserB := FMatrixItem[B];

  if Length(UserA) <> Length(UserB) then
    raise Exception.Create('Os vetores A e B têm tamanhos diferentes.');

  for i := 0 to High(UserA) do
  begin
    if not IsNan(UserA[i]) and not IsNan(UserB[i]) then
    begin
      SumA := SumA + UserA[i];
      SumB := SumB + UserB[i];
      SumASq := SumASq + Sqr(UserA[i]);
      SumBSq := SumBSq + Sqr(UserB[i]);
      SumAB := SumAB + (UserA[i] * UserB[i]);
      Inc(N);
    end;
  end;

  if N = 0 then
  begin
    Result := 0; 
    Exit;
  end;

  MeanA := SumA / N;
  MeanB := SumB / N;

  SumASq := 0;
  SumBSq := 0;
  SumAB := 0;
  for i := 0 to High(UserA) do
  begin
    if not IsNan(UserA[i]) and not IsNan(UserB[i]) then
    begin
      SumASq := SumASq + Sqr(UserA[i] - MeanA);
      SumBSq := SumBSq + Sqr(UserB[i] - MeanB);
      SumAB := SumAB + ((UserA[i] - MeanA) * (UserB[i] - MeanB));
    end;
  end;

  if (SumASq = 0) or (SumBSq = 0) then
  begin
    Result := 0; 
    Exit;
  end;

  Result := SumAB / Sqrt(SumASq * SumBSq);
end;



function TRecommender.CalculateDistance(A, B: Integer; IsUserBased: Boolean; ArrayA: TArray<Double> = nil; ArrayB: TArray<Double> = nil): Double;
begin
  case FDistanceMethod of
    dmManhattan:
      Result := CalculateManhattanDistance(A, B, IsUserBased, ArrayA, ArrayB);
    dmEuclidean:
      Result := CalculateEuclideanDistance(A, B, IsUserBased, ArrayA, ArrayB);
    dmCosine:
      Result := CalculateCosineSimilarity(A, B, IsUserBased, ArrayA, ArrayB);
    dmJaccard:
      Result := CalculateJaccardDistance(A, B, IsUserBased, ArrayA, ArrayB);
    dmPearson:
      Result := CalculatePearsonCorrelation(A, B, IsUserBased, ArrayA, ArrayB);
  else
    raise Exception.Create('Invalid distance mode');
  end;
  if IsNan(Result) then begin
    Result := 0;
  end;
end;

procedure TRecommender.CalculateUserRecall(out UserRecall: Double; aItemsToTest : TArray<TArray<Integer>>);
var
  vBkpMatrix: TAIDatasetRecommendation;
  i, j, k : Integer;
  vQtdTestes,
  userHitCount, totalUserTests: Integer;
  recommendedItems: TArray<Integer>;
begin
  FTrainingUser := True;
  try
    SetLength(vBkpMatrix, Length(FDataset), Length(FDataset[0]));
    for i := 0 to getNumUsers - 1 do begin
      for j := 0 to getNumItems - 1 do begin
        vBkpMatrix[i][j] := FDataset[i][j];
      end;
    end;

    userHitCount := 0;
    totalUserTests := 0;

    if getNumUsers > 8000 then begin
      vQtdTestes := 8000;
    end else begin
      vQtdTestes := getNumUsers;
    end;

    for i := getNumUsers - vQtdTestes to getNumUsers - 1 do begin
      for j in aItemsToTest[i] do begin
        FDataset[i][j] := 0;
        recommendedItems := RecommendFromUser(i);
        for k := 0 to High(recommendedItems) do begin
          if j = recommendedItems[k] then begin
            Inc(userHitCount);
            Break;
          end;
        end;

        FDataset[i][j] := vBkpMatrix[i][j];

        Inc(totalUserTests);
      end;
    end;

    if totalUserTests > 0 then begin
      UserRecall := userHitCount / totalUserTests;
    end else begin
      UserRecall := 0.0;
    end;
  finally
    FTrainingUser := False;
  end;
end;

procedure TRecommender.CalculateItemRecall(out ItemRecall: Double);
var
  vBkpMatrixItem: TAIDatasetRecommendation;
  i, j, k, l : Integer;
  vQtdTestes,
  itemHitCount, totalItemTests: Integer;
  recommendedItems: TArray<Integer>;
  vEncontrou : Boolean;
begin
  vBkpMatrixItem := Copy(FMatrixItem);

  itemHitCount := 0;
  totalItemTests := 0;

  if getNumUsers > 100000 then begin
    vQtdTestes := 100000;
  end else begin
    vQtdTestes := getNumUsers;
  end;

  for i := getNumUsers - vQtdTestes to getNumUsers - 1 do begin
    for j := 0 to getNumItems - 1 do begin
      if FDataset[i][j] > 0 then begin
        vEncontrou := False;
        for k := 0 to getNumItems - 1 do begin
          if (k <> j) and (FDataset[i][k] > 0) then begin
            recommendedItems := RecommendFromItem(k);
            for l := 0 to High(recommendedItems) do begin
              if j = recommendedItems[l] then begin
                Inc(itemHitCount);
                vEncontrou := True;
                Break;
              end;
            end;
            if vEncontrou then begin
              Break;
            end;
          end;
        end;
        Inc(totalItemTests);
      end;
    end;
  end;
  if totalItemTests > 0 then
    ItemRecall := itemHitCount / totalItemTests
  else
    ItemRecall := 0.0;
end;

function TRecommender.RecommendFromUser(aUserID: Integer): TArray<Integer>;
begin
  Result := RecommendFromUser(FDataset[aUserID], aUserID);
end;

function TRecommender.RecommendFromItem(aItemInfo: TArray<Double>; aIDSearch : Integer = -1): TArray<Integer>;
var
  vDistances: TArray<Double>;
  BestItemIndices: TArray<Integer>;
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
  SetLength(BestItemIndices, getNumItems);
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
    BestItemIndices[i] := i;
  end;

  if FDistanceMethod in [dmCosine, dmPearson] then begin
    TArray.Sort<Integer>(BestItemIndices,
      TComparer<Integer>.Construct(
        function(const Left, Right: Integer): Integer
        begin
          Result := CompareValue(vDistances[Right], vDistances[Left]);
        end
      )
    );
  end else begin
    TArray.Sort<Integer>(BestItemIndices,
      TComparer<Integer>.Construct(
        function(const Left, Right: Integer): Integer
        begin
          Result := CompareValue(vDistances[Left], vDistances[Right]);
        end
      )
    );
  end;

  SetLength(BestItemIndices, ItemsToRecommendCount);

  Result := BestItemIndices;

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
  BestUserIndices: TArray<Integer>;
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
  SetLength(BestUserIndices, getNumUsers);
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
    BestUserIndices[i] := i;
  end;
  vOta := vDistances;

  if FDistanceMethod in [dmCosine, dmPearson] then begin
    TArray.Sort<Integer>(BestUserIndices,
      TComparer<Integer>.Construct(
        function(const Left, Right: Integer): Integer
        begin
          Result := CompareValue(vDistances[Right], vDistances[Left]);
        end
      )
    );
  end else begin
    TArray.Sort<Integer>(BestUserIndices,
      TComparer<Integer>.Construct(
        function(const Left, Right: Integer): Integer
        begin
          Result := CompareValue(vDistances[Left], vDistances[Right]);
        end
      )
    );
  end;

  SetLength(BestUserIndices, FK);

  for i := 0 to FK - 1 do begin
    vRatesRec[i] := FDataset[BestUserIndices[i]];
    vFilteredDistances[i] := vDistances[BestUserIndices[i]];
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
  ItemFrequency: TDictionary<Integer, Integer>;
  Item, Count, i: Integer;
  SortedItems: TArray<Integer>;
begin
  ItemFrequency := TDictionary<Integer, Integer>.Create;
  try
    for i := 0 to getNumUsers - 1 do
    begin
      for Item := 0 to getNumItems - 1 do
      begin
        if FDataset[i][Item] > 0 then
        begin
          if not ItemFrequency.TryGetValue(Item, Count) then
            Count := 0;
          ItemFrequency[Item] := Count + 1;
        end;
      end;
    end;

    SortedItems := ItemFrequency.Keys.ToArray;
    TArray.Sort<Integer>(SortedItems, TComparer<Integer>.Construct(
      function(const Left, Right: Integer): Integer
      begin
        Result := ItemFrequency[Right] - ItemFrequency[Left];
      end
    ));

    SetLength(Result, Min(FItemsToRecommendCount, Length(SortedItems)));
    for i := 0 to High(Result) do
      Result[i] := SortedItems[i];
  finally
    ItemFrequency.Free;
  end;
end;
function TRecommender.GetRecommendedItems(const aRate: TAIDatasetRecommendation; aProximity, aConsumedItems: TArray<Double>; aTopN: Integer; Method: TUserScoreAggregationMethod): TArray<Integer>;
var
  i, j: Integer;
  ItemScores: TArray<Double>;
  RankedItems: TArray<Integer>;
begin
  SetLength(ItemScores, getNumItems);
  for i := 0 to getNumItems - 1 do
    ItemScores[i] := 0.0;
 
  for i := 0 to Length(aProximity) - 1 do begin
    
    if aProximity[i] = 0 then
      Continue;

    for j := 0 to getNumItems - 1 do begin
      if (aConsumedItems[j] <= 0) and (aRate[i][j] > 0) then begin
        case Method of
          amMode:
            ItemScores[j] := ItemScores[j] + 1; 
          amWeightedAverage:
            ItemScores[j] := ItemScores[j] + (aRate[i][j] * aProximity[i]);
          amSimpleSum:
            ItemScores[j] := ItemScores[j] + aRate[i][j]; 
        end;
      end;
    end;
  end;

  SetLength(RankedItems, getNumItems);
  for i := 0 to getNumItems - 1 do
    RankedItems[i] := i;

  TArray.Sort<Integer>(RankedItems, TComparer<Integer>.Construct(
    function(const Left, Right: Integer): Integer
    begin
      if ItemScores[Left] > ItemScores[Right] then
        Result := -1
      else if ItemScores[Left] < ItemScores[Right] then
        Result := 1
      else
        Result := 0;
    end));

  SetLength(Result, aTopN);
  for i := 0 to aTopN - 1 do
    Result[i] := RankedItems[i];
end;


end.

