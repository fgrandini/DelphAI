unit UDecisionTree;

interface

uses
  SysUtils, Classes, Math, Generics.Collections, System.JSON, UAITypes, UAIModel,
  Data.DB;

type
  TDecisionTreeNode = class
  private
  public
    FeatureIndex: Integer;
    Threshold: Double;
    LeftChild, RightChild: TDecisionTreeNode;
    LabelValue: String;
    destructor Destroy; override;
  end;

  TDecisionTree = class(TClassificationModel)
  private
    FRoot: TDecisionTreeNode;
    FCriterion: TSplitCriterion;
    FDepth : Integer;
    function CalculateEntropy(const aLabels: TAILabelsClassification): Double;
    function CalculateGini(const aLabels: TAILabelsClassification): Double;
    function InformationGain(const aLabels: TAILabelsClassification; const aFeatureValues: TArray<Double>; aThreshold: Double): Double;
    function BuildTree(const aData: TAISamplesAtr; const aLabels: TAILabelsClassification; aDepth: Integer): TDecisionTreeNode;
    function PredictNode(aNode: TDecisionTreeNode; const aSample: TArray<Double>): String;
  public
    constructor Create(aDepth: Integer; aSplitCriterion: TSplitCriterion); overload;
    constructor Create(aTrainedFile : String); overload;
    destructor Destroy; override;
    procedure Train(aTrainingData : TAIDatasetClassification; aNormalizationRange : TNormalizationRange); overload;
    procedure Train(aTrainingData : String; aHasHeader : Boolean = True); overload;
    procedure Train(aTrainingData : TDataSet); overload;
    procedure LoadFromJson(aJson : TJSONObject);

    function Predict(aSample: TArray<Double>; aInputNormalized : Boolean = False): String;
    procedure LoadFromFile(const aFileName: string);
    procedure SaveToFile(const aFileName: string);
    function TreeToJSON: TJSONObject;
    property Root : TDecisionTreeNode read FRoot write FRoot;
  end;
  function JSONToNode(aJSONNode: TJSONObject): TDecisionTreeNode;
  function NodeToJSON(aNode: TDecisionTreeNode): TJSONObject;

implementation

uses
  UAuxGlobal;

constructor TDecisionTree.Create(aDepth: Integer; aSplitCriterion: TSplitCriterion);
begin
  FCriterion := aSplitCriterion;
  FDepth := aDepth;
  FRoot := nil;
end;

constructor TDecisionTree.Create(aTrainedFile : String);
begin
  FCriterion := TSplitCriterion.scEntropy;
  FDepth := 0;
  LoadFromFile(aTrainedFile);
end;

destructor TDecisionTree.Destroy;
begin
  FRoot.Free;
  inherited;
end;

function TDecisionTree.CalculateEntropy(const aLabels: TAILabelsClassification): Double;
var
  vLabelCounts: array of Integer;
  vUniqueLabels: TDictionary<String, Integer>;
  vTotal, i, vCount: Integer;
  vProbability: Double;
  vEntropy: Double;
  vLabelValue: String;
  vLabelIndex: Integer;
begin
  vTotal := Length(aLabels);
  vUniqueLabels := TDictionary<String, Integer>.Create;
  try
    for vLabelValue in aLabels do begin
      if not vUniqueLabels.ContainsKey(vLabelValue) then begin
        vUniqueLabels.Add(vLabelValue, vUniqueLabels.Count);
      end;
    end;

    SetLength(vLabelCounts, vUniqueLabels.Count);
    for i := 0 to vTotal - 1 do begin
      vLabelIndex := vUniqueLabels[aLabels[i]];
      Inc(vLabelCounts[vLabelIndex]);
    end;

    vEntropy := 0.0;
    for vCount in vLabelCounts do begin
      vProbability := vCount / vTotal;
      vEntropy := vEntropy - (vProbability * Log2(vProbability + 1e-10));
    end;

    Result := vEntropy;
  finally
    vUniqueLabels.Free;
  end;
end;


function TDecisionTree.CalculateGini(const aLabels: TAILabelsClassification): Double;
var
  vLabelCounts: TDictionary<String, Integer>;
  vTotal, vCount : Integer;
  vProbability : Double;
  vGini : Double;
  vLabelValue : String;
begin
  vLabelCounts := TDictionary<String, Integer>.Create;
  try
    for vLabelValue in aLabels do begin
      if not vLabelCounts.ContainsKey(vLabelValue) then begin
        vLabelCounts.Add(vLabelValue, 0);
      end;
      vLabelCounts[vLabelValue] := vLabelCounts[vLabelValue] + 1;
    end;

    vTotal := Length(aLabels);
    vGini := 1.0;

    for vCount in vLabelCounts.Values do begin
      vProbability := vCount / vTotal;
      vGini := vGini - Sqr(vProbability);
    end;

    Result := vGini;
  finally
    vLabelCounts.Free;
  end;
end;

function TDecisionTree.InformationGain(const aLabels: TAILabelsClassification; const aFeatureValues: TArray<Double>; aThreshold: Double): Double;
var
  vLeftLabels, vRightLabels: TArray<String>;
  i, vLeftCount, vRightCount: Integer;
  vMetricBefore, vMetricLeft, vMetricRight: Double;
  vUseEntropy: Boolean;
begin
  SetLength(vLeftLabels, Length(aLabels));
  SetLength(vRightLabels, Length(aLabels));
  vLeftCount := 0;
  vRightCount := 0;

  vUseEntropy := FCriterion = scEntropy;

  for i := 0 to Length(aFeatureValues) - 1 do begin
    if aFeatureValues[i] <= aThreshold then begin
      vLeftLabels[vLeftCount] := aLabels[i];
      Inc(vLeftCount);
    end else begin
      vRightLabels[vRightCount] := aLabels[i];
      Inc(vRightCount);
    end;
  end;

  SetLength(vLeftLabels, vLeftCount);
  SetLength(vRightLabels, vRightCount);

  if vUseEntropy then
    vMetricBefore := CalculateEntropy(aLabels)
  else
    vMetricBefore := CalculateGini(aLabels);

  if vUseEntropy then begin
    vMetricLeft := CalculateEntropy(vLeftLabels);
    vMetricRight := CalculateEntropy(vRightLabels);
  end else begin
    vMetricLeft := CalculateGini(vLeftLabels);
    vMetricRight := CalculateGini(vRightLabels);
  end;

  Result := vMetricBefore - ((vLeftCount / Length(aLabels)) * vMetricLeft) -
            ((vRightCount / Length(aLabels)) * vMetricRight);
end;

function TDecisionTree.BuildTree(const aData: TAISamplesAtr; const aLabels: TAILabelsClassification; aDepth: Integer): TDecisionTreeNode;
var
  vBestFeatureIndex : Integer;
  vBestThreshold, vBestGain, vGain : Double;
  vFeatureValues : TArray<Double>;
  vThreshold : Double;
  i, j: Integer;
  vNode : TDecisionTreeNode;
  vLeftData, vRightData: TList<TArray<Double>>;
  vLeftLabels, vRightLabels: TList<String>;
begin
  if (Length(aData) = 0) or (aDepth = 0) then begin
    vNode := TDecisionTreeNode.Create;
    vNode.LabelValue := aLabels[0];
    Exit(vNode);
  end;

  vBestGain := -1;
  vBestFeatureIndex := -1;
  vBestThreshold := 0;

  for i := 0 to Length(aData[0]) - 1 do begin
    SetLength(vFeatureValues, Length(aData));
    for j := 0 to Length(aData) - 1 do begin
      vFeatureValues[j] := aData[j][i];
    end;

    for j := 0 to Length(vFeatureValues) - 1 do begin
      vThreshold := vFeatureValues[j];
      vGain := InformationGain(aLabels, vFeatureValues, vThreshold);

      if vGain > vBestGain then
      begin
        vBestGain := vGain;
        vBestFeatureIndex := i;
        vBestThreshold := vThreshold;
      end;
    end;
  end;

  if vBestGain = 0 then begin
    vNode := TDecisionTreeNode.Create;
    vNode.LabelValue := aLabels[0];
    Exit(vNode);
  end;

  vNode := TDecisionTreeNode.Create;
  vNode.FeatureIndex := vBestFeatureIndex;
  vNode.Threshold := vBestThreshold;

  vLeftData := TList<TArray<Double>>.Create;
  vRightData := TList<TArray<Double>>.Create;
  vLeftLabels := TList<String>.Create;
  vRightLabels := TList<String>.Create;
  try
    for j := 0 to Length(aData) - 1 do begin
      if aData[j][vBestFeatureIndex] <= vBestThreshold then begin
        vLeftData.Add(aData[j]);
        vLeftLabels.Add(aLabels[j]);
      end else begin
        vRightData.Add(aData[j]);
        vRightLabels.Add(aLabels[j]);
      end;
    end;

    vNode.LeftChild := BuildTree(vLeftData.ToArray, vLeftLabels.ToArray, aDepth - 1);
    vNode.RightChild := BuildTree(vRightData.ToArray, vRightLabels.ToArray, aDepth - 1);
  finally
    vLeftData.Free;
    vRightData.Free;
    vLeftLabels.Free;
    vRightLabels.Free;
  end;

  Result := vNode;
end;

function TDecisionTree.Predict(aSample : TArray<Double>; aInputNormalized : Boolean = False): String;
begin
  aSample := Copy(aSample);
  if not aInputNormalized then begin
    ValidateAndNormalizeInput(aSample);
  end;
  Result := PredictNode(FRoot, aSample);
end;

function TDecisionTree.PredictNode(aNode: TDecisionTreeNode; const aSample: TArray<Double>): String;
begin
  if aNode.LeftChild = nil then begin
    Exit(aNode.LabelValue);
  end;

  if aSample[aNode.FeatureIndex] <= aNode.Threshold then begin
    Result := PredictNode(aNode.LeftChild, aSample)
  end else begin
    Result := PredictNode(aNode.RightChild, aSample);
  end;
end;

function NodeToJSON(aNode: TDecisionTreeNode): TJSONObject;
var
  vJSONNode: TJSONObject;
begin
  vJSONNode := TJSONObject.Create;

  vJSONNode.AddPair('FeatureIndex', TJSONNumber.Create(aNode.FeatureIndex));
  vJSONNode.AddPair('Threshold', TJSONNumber.Create(aNode.Threshold));
  if aNode.LabelValue <> '' then
    vJSONNode.AddPair('LabelValue', aNode.LabelValue);

  if Assigned(aNode.LeftChild) then
    vJSONNode.AddPair('LeftChild', NodeToJSON(aNode.LeftChild));

  if Assigned(aNode.RightChild) then
    vJSONNode.AddPair('RightChild', NodeToJSON(aNode.RightChild));

  Result := vJSONNode;
end;

procedure TDecisionTree.Train(aTrainingData: TAIDatasetClassification; aNormalizationRange: TNormalizationRange);
var
  vLabels: TAILabelsClassification;
  vData: TAISamplesAtr;
begin
  FNormalizationRange := aNormalizationRange;
  FDataset := Copy(aTrainingData);
  SplitLabelAndSampleDataset(FDataset, vData, vLabels);
  PopulateInputLenght;
  FRoot := BuildTree(vData, vLabels, FDepth);
  Trained := True;
end;

procedure TDecisionTree.Train(aTrainingData: String; aHasHeader: Boolean);
var
  vLabels: TAILabelsClassification;
  vData: TAISamplesAtr;
begin
  LoadDataset(aTrainingData, FDataset, FNormalizationRange, aHasHeader);

  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;

  SplitLabelAndSampleDataset(FDataset, vData, vLabels);
  PopulateInputLenght;
  FRoot := BuildTree(vData, vLabels, FDepth);
  Trained := True;
end;

procedure TDecisionTree.Train(aTrainingData: TDataSet);
var
  vLabels: TAILabelsClassification;
  vData: TAISamplesAtr;
begin
  if aTrainingData.RecordCount = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;

  LoadDataset(aTrainingData, FDataset, FNormalizationRange);

  SplitLabelAndSampleDataset(FDataset, vData, vLabels);
  PopulateInputLenght;
  FRoot := BuildTree(vData, vLabels, FDepth);
  Trained := True;
end;

function TDecisionTree.TreeToJSON: TJSONObject;
var
  vJson : TJSONObject;
begin
  vJson := TJSONObject.Create;
  vJson.AddPair('NormalizationRange', NormRangeToJSON);
  vJson.AddPair('InputLength', TJSONNumber.Create(InputLength));
  vJson.AddPair('Root', NodeToJSON(FRoot));
  Result := vJson;
end;

procedure TDecisionTree.SaveToFile(const aFileName: string);
var
  vJSONTree: TJSONObject;
  vJSONString: string;
  vFileStream: TFileStream;
  vBytes: TBytes;
begin
  vJSONTree := TreeToJSON;
  try
    vJSONString := vJSONTree.ToString;
    vBytes := TEncoding.UTF8.GetBytes(vJSONString);

    vFileStream := TFileStream.Create(aFileName, fmCreate);
    try
      vFileStream.Write(vBytes[0], Length(vBytes));
    finally
      vFileStream.Free;
    end;
  finally
    vJSONTree.Free;
  end;
end;

function JSONToNode(aJSONNode: TJSONObject): TDecisionTreeNode;
var
  vNode: TDecisionTreeNode;
  vLeftChildJSON, vRightChildJSON: TJSONObject;
begin
  vNode := TDecisionTreeNode.Create;

  vNode.FeatureIndex := aJSONNode.GetValue<Integer>('FeatureIndex');
  vNode.Threshold := aJSONNode.GetValue<Double>('Threshold');
  if aJSONNode.TryGetValue('LabelValue', vNode.LabelValue) then
    vNode.LabelValue := aJSONNode.GetValue<string>('LabelValue');

  if aJSONNode.TryGetValue('LeftChild', vLeftChildJSON) then
    vNode.LeftChild := JSONToNode(vLeftChildJSON);

  if aJSONNode.TryGetValue('RightChild', vRightChildJSON) then
    vNode.RightChild := JSONToNode(vRightChildJSON);

  Result := vNode;
end;

procedure TDecisionTree.LoadFromFile(const aFileName: string);
var
  vJson: TJSONObject;
  vJSONString: string;
  vFileStream: TFileStream;
  vBytes: TBytes;
  vSize: Integer;
begin
  vFileStream := TFileStream.Create(aFileName, fmOpenRead);
  try
    vSize := vFileStream.Size;
    SetLength(vBytes, vSize);
    vFileStream.Read(vBytes[0], vSize);
    vJSONString := TEncoding.UTF8.GetString(vBytes);

    vJson := TJSONObject.ParseJSONValue(vJSONString) as TJSONObject;
    try
      FRoot := JSONToNode(vJson.FindValue('Root') as TJSONObject);
      InputLength := StrToInt(vJson.FindValue('InputLength').Value);
      JSONToNormRange(vJson.FindValue('NormalizationRange') as TJSONObject);
      Trained := True;
    finally
      vJson.Free;
    end;
  finally
    vFileStream.Free;
  end;
end;

procedure TDecisionTree.LoadFromJson(aJson : TJSONObject);
begin
  InputLength := StrToInt(aJson.FindValue('InputLength').Value);
  JSONToNormRange(aJson.FindValue('NormalizationRange') as TJSONObject);
  Root := JSONToNode(aJson.FindValue('Root') as TJSONObject);
  Trained := True;
end;


{ TDecisionTreeNode }

destructor TDecisionTreeNode.Destroy;
begin
  LeftChild.Free;
  RightChild.Free;
  inherited;
end;

end.

