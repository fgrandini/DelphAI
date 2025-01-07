unit UDBSCAN;

interface

uses
  System.SysUtils, System.Math, System.Generics.Collections, Data.DB, UAIModel;

type
  TAISampleAtr = TArray<Double>;
  TAIDatasetClustering = TArray<TAISampleAtr>;

  function DBSCAN(aData : String; aEps: Double; aMinPts: Integer; aHasHeader : Boolean = True): TArray<Integer>; overload;
  function DBSCAN(aData : TDataSet; aEps: Double; aMinPts: Integer): TArray<Integer>; overload;
  function DBSCAN(aData : TAIDatasetClustering; aEps: Double; aMinPts: Integer): TArray<Integer>; overload;

implementation

uses
  UAuxGlobal, UAITypes;

function Distance(const A, B: TAISampleAtr): Double;
var
  i: Integer;
  Sum: Double;
begin
  Sum := 0.0;
  for i := Low(A) to High(A) do
    Sum := Sum + Sqr(A[i] - B[i]);
  Result := Sqrt(Sum);
end;

function RegionQuery(const aData: TAIDatasetClustering; const PointIdx: Integer; aEps: Double): TList<Integer>;
var
  i: Integer;
begin
  Result := TList<Integer>.Create;
  for i := 0 to High(aData) do
  begin
    if Distance(aData[PointIdx], aData[i]) <= aEps then
      Result.Add(i);
  end;
end;

procedure ExpandCluster(const aData: TAIDatasetClustering; const PointIdx: Integer; const Neighbors: TList<Integer>; ClusterIdx: Integer; var Labels: TArray<Integer>; aEps: Double; aMinPts: Integer);
var
  i, NeighborIdx: Integer;
  NewNeighbors: TList<Integer>;
begin
  Labels[PointIdx] := ClusterIdx;

  i := 0;
  while i < Neighbors.Count do
  begin
    NeighborIdx := Neighbors[i];

    if Labels[NeighborIdx] = -1 then
    begin
      Labels[NeighborIdx] := ClusterIdx;
      NewNeighbors := RegionQuery(aData, NeighborIdx, aEps);
      try
        if NewNeighbors.Count >= aMinPts then
          Neighbors.AddRange(NewNeighbors);
      finally
        NewNeighbors.Free;
      end;
    end;

    Inc(i);
  end;
end;

function DBSCAN(aData : String; aEps: Double; aMinPts: Integer; aHasHeader : Boolean = True): TArray<Integer>; overload;
var
  vDataSet : TAIDatasetClustering;
  vNormRange : TNormalizationRange;
begin
  LoadDataset(aData, vDataSet, vNormRange, aHasHeader);
  Result := DBSCAN(vDataSet, aEps, aMinPts);
end;

function DBSCAN(aData : TDataSet; aEps: Double; aMinPts: Integer): TArray<Integer>; overload;
var
  vDataSet : TAIDatasetClustering;
  vNormRange : TNormalizationRange;
begin
  if aData.RecordCount = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;

  LoadDataset(aData, vDataSet, vNormRange);
  Result := DBSCAN(vDataSet, aEps, aMinPts);
end;


function DBSCAN(aData: TAIDatasetClustering; aEps: Double; aMinPts: Integer): TArray<Integer>;
var
  i: Integer;
  Neighbors: TList<Integer>;
  ClusterIdx: Integer;
  Labels: TArray<Integer>;
begin
  SetLength(Labels, Length(aData));
  FillChar(Labels[0], Length(Labels) * SizeOf(Integer), -1); 

  ClusterIdx := 0;

  for i := 0 to High(aData) do
  begin
    if Labels[i] <> -1 then
      Continue;

    Neighbors := RegionQuery(aData, i, aEps);
    try
      if Neighbors.Count < aMinPts then
        Labels[i] := 0  
      else
      begin
        Inc(ClusterIdx);
        ExpandCluster(aData, i, Neighbors, ClusterIdx, Labels, aEps, aMinPts);
      end;
    finally
      Neighbors.Free;
    end;
  end;

  Result := Labels;
end;

end.

