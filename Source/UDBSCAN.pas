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
  function RegionQuery(const aData: TAIDatasetClustering; const aPointIdx: Integer; aEps: Double): TList<Integer>;
  procedure ExpandCluster(const aData: TAIDatasetClustering; const aPointIdx: Integer; const aNeighbors: TList<Integer>; aClusterIdx: Integer; var aLabels: TArray<Integer>; aEps: Double; aMinPts: Integer);

implementation

uses
  UAuxGlobal, UAITypes;

function RegionQuery(const aData: TAIDatasetClustering; const aPointIdx: Integer; aEps: Double): TList<Integer>;
var
  i: Integer;
begin
  Result := TList<Integer>.Create;
  for i := 0 to High(aData) do
  begin
    if Distance(aData[aPointIdx], aData[i]) <= aEps then
      Result.Add(i);
  end;
end;

procedure ExpandCluster(const aData: TAIDatasetClustering; const aPointIdx: Integer; const aNeighbors: TList<Integer>; aClusterIdx: Integer; var aLabels: TArray<Integer>; aEps: Double; aMinPts: Integer);
var
  i, vNeighborIdx: Integer;
  vNewNeighbors: TList<Integer>;
begin
  aLabels[aPointIdx] := aClusterIdx;

  i := 0;
  while i < aNeighbors.Count do
  begin
    vNeighborIdx := aNeighbors[i];

    if aLabels[vNeighborIdx] = -1 then
    begin
      aLabels[vNeighborIdx] := aClusterIdx;
      vNewNeighbors := RegionQuery(aData, vNeighborIdx, aEps);
      try
        if vNewNeighbors.Count >= aMinPts then
          aNeighbors.AddRange(vNewNeighbors);
      finally
        vNewNeighbors.Free;
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
  vNeighbors: TList<Integer>;
  vClusterIdx: Integer;
  vLabels: TArray<Integer>;
begin
  SetLength(vLabels, Length(aData));
  FillChar(vLabels[0], Length(vLabels) * SizeOf(Integer), -1);

  vClusterIdx := 0;

  for i := 0 to High(aData) do
  begin
    if vLabels[i] <> -1 then
      Continue;

    vNeighbors := RegionQuery(aData, i, aEps);
    try
      if vNeighbors.Count < aMinPts then
        vLabels[i] := 0
      else
      begin
        Inc(vClusterIdx);
        ExpandCluster(aData, i, vNeighbors, vClusterIdx, vLabels, aEps, aMinPts);
      end;
    finally
      vNeighbors.Free;
    end;
  end;

  Result := vLabels;
end;

end.

