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
    function CalculateEntropy(const Labels: TAILabelsClassification): Double;
    function CalculateGini(const Labels: TAILabelsClassification): Double;
    function InformationGain(const Labels: TAILabelsClassification; const FeatureValues: TArray<Double>; Threshold: Double): Double;
    function BuildTree(const Data: TAISamplesAtr; const Labels: TAILabelsClassification; Depth: Integer): TDecisionTreeNode;
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
    procedure LoadFromFile(const FileName: string);
    procedure SaveToFile(const FileName: string);
    function TreeToJSON: TJSONObject;
    property Root : TDecisionTreeNode read FRoot write FRoot;
  end;
  function JSONToNode(JSONNode: TJSONObject): TDecisionTreeNode;

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

function TDecisionTree.CalculateEntropy(const Labels: TAILabelsClassification): Double;
var
  vLabelCounts: array of Integer;
  vUniqueLabels: TDictionary<String, Integer>;
  Total, i, Count: Integer;
  vProbability: Double;
  vEntropy: Double;
  LabelValue: String;
  LabelIndex: Integer;
begin
  Total := Length(Labels);
  vUniqueLabels := TDictionary<String, Integer>.Create;
  try
    for LabelValue in Labels do begin
      if not vUniqueLabels.ContainsKey(LabelValue) then begin
        vUniqueLabels.Add(LabelValue, vUniqueLabels.Count);
      end;
    end;

    SetLength(vLabelCounts, vUniqueLabels.Count);
    for i := 0 to Total - 1 do begin
      LabelIndex := vUniqueLabels[Labels[i]];
      Inc(vLabelCounts[LabelIndex]);
    end;

    vEntropy := 0.0;
    for Count in vLabelCounts do begin
      vProbability := Count / Total;
      vEntropy := vEntropy - (vProbability * Log2(vProbability + 1e-10));  
    end;

    Result := vEntropy;
  finally
    vUniqueLabels.Free;
  end;
end;


function TDecisionTree.CalculateGini(const Labels: TAILabelsClassification): Double;
var
  vLabelCounts: TDictionary<String, Integer>;
  vTotal, vCount : Integer;
  vProbability : Double;
  vGini : Double;
  vLabelValue : String;
begin
  vLabelCounts := TDictionary<String, Integer>.Create;
  try
    for vLabelValue in Labels do begin
      if not vLabelCounts.ContainsKey(vLabelValue) then begin
        vLabelCounts.Add(vLabelValue, 0);
      end;
      vLabelCounts[vLabelValue] := vLabelCounts[vLabelValue] + 1;
    end;

    vTotal := Length(Labels);
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

function TDecisionTree.InformationGain(const Labels: TAILabelsClassification; const FeatureValues: TArray<Double>; Threshold: Double): Double;
var
  vLeftLabels, vRightLabels: TArray<String>;
  i, LeftCount, RightCount: Integer;
  vMetricBefore, vMetricLeft, vMetricRight: Double;
  UseEntropy: Boolean;
begin
  SetLength(vLeftLabels, Length(Labels));
  SetLength(vRightLabels, Length(Labels));
  LeftCount := 0;
  RightCount := 0;

  UseEntropy := FCriterion = scEntropy;

  for i := 0 to Length(FeatureValues) - 1 do begin
    if FeatureValues[i] <= Threshold then begin
      vLeftLabels[LeftCount] := Labels[i];
      Inc(LeftCount);
    end else begin
      vRightLabels[RightCount] := Labels[i];
      Inc(RightCount);
    end;
  end;

  SetLength(vLeftLabels, LeftCount);
  SetLength(vRightLabels, RightCount);

  if UseEntropy then
    vMetricBefore := CalculateEntropy(Labels)
  else
    vMetricBefore := CalculateGini(Labels);

  if UseEntropy then begin
    vMetricLeft := CalculateEntropy(vLeftLabels);
    vMetricRight := CalculateEntropy(vRightLabels);
  end else begin
    vMetricLeft := CalculateGini(vLeftLabels);
    vMetricRight := CalculateGini(vRightLabels);
  end;

  Result := vMetricBefore - ((LeftCount / Length(Labels)) * vMetricLeft) -
            ((RightCount / Length(Labels)) * vMetricRight);
end;

function TDecisionTree.BuildTree(const Data: TAISamplesAtr; const Labels: TAILabelsClassification; Depth: Integer): TDecisionTreeNode;
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
  if (Length(Data) = 0) or (Depth = 0) then begin
    vNode := TDecisionTreeNode.Create;
    vNode.LabelValue := Labels[0]; 
    Exit(vNode);
  end;

  vBestGain := -1;
  vBestFeatureIndex := -1;
  vBestThreshold := 0;

  for i := 0 to Length(Data[0]) - 1 do begin
    SetLength(vFeatureValues, Length(Data));
    for j := 0 to Length(Data) - 1 do begin
      vFeatureValues[j] := Data[j][i];
    end;

    for j := 0 to Length(vFeatureValues) - 1 do begin
      vThreshold := vFeatureValues[j];
      vGain := InformationGain(Labels, vFeatureValues, vThreshold);

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
    vNode.LabelValue := Labels[0];
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
    for j := 0 to Length(Data) - 1 do begin
      if Data[j][vBestFeatureIndex] <= vBestThreshold then begin
        vLeftData.Add(Data[j]);
        vLeftLabels.Add(Labels[j]);
      end else begin
        vRightData.Add(Data[j]);
        vRightLabels.Add(Labels[j]);
      end;
    end;

    vNode.LeftChild := BuildTree(vLeftData.ToArray, vLeftLabels.ToArray, Depth - 1);
    vNode.RightChild := BuildTree(vRightData.ToArray, vRightLabels.ToArray, Depth - 1);
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

function NodeToJSON(Node: TDecisionTreeNode): TJSONObject;
var
  JSONNode: TJSONObject;
begin
  JSONNode := TJSONObject.Create;

  JSONNode.AddPair('FeatureIndex', TJSONNumber.Create(Node.FeatureIndex));
  JSONNode.AddPair('Threshold', TJSONNumber.Create(Node.Threshold));
  if Node.LabelValue <> '' then
    JSONNode.AddPair('LabelValue', Node.LabelValue);

  if Assigned(Node.LeftChild) then
    JSONNode.AddPair('LeftChild', NodeToJSON(Node.LeftChild));

  if Assigned(Node.RightChild) then
    JSONNode.AddPair('RightChild', NodeToJSON(Node.RightChild));

  Result := JSONNode;
end;

procedure TDecisionTree.Train(aTrainingData: TAIDatasetClassification; aNormalizationRange: TNormalizationRange);
var
  Labels: TAILabelsClassification;
  Data: TAISamplesAtr;
begin
  FNormalizationRange := aNormalizationRange;
  FDataset := Copy(aTrainingData);
  SplitLabelAndSampleDataset(FDataset, Data, Labels);
  PopulateInputLenght;
  FRoot := BuildTree(Data, Labels, FDepth);
  Trained := True;
end;

procedure TDecisionTree.Train(aTrainingData: String; aHasHeader: Boolean);
var
  Labels: TAILabelsClassification;
  Data: TAISamplesAtr;
begin
  LoadDataset(aTrainingData, FDataset, FNormalizationRange, aHasHeader);

  if Length(FDataset) = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;

  SplitLabelAndSampleDataset(FDataset, Data, Labels);
  PopulateInputLenght;
  FRoot := BuildTree(Data, Labels, FDepth);
  Trained := True;
end;

procedure TDecisionTree.Train(aTrainingData: TDataSet);
var
  Labels: TAILabelsClassification;
  Data: TAISamplesAtr;
begin
  if aTrainingData.RecordCount = 0 then begin
    raise Exception.Create('Dataset is empty.');
  end;

  LoadDataset(aTrainingData, FDataset, FNormalizationRange);

  SplitLabelAndSampleDataset(FDataset, Data, Labels);
  PopulateInputLenght;
  FRoot := BuildTree(Data, Labels, FDepth);
  Trained := True;
end;

function TDecisionTree.TreeToJSON: TJSONObject;
var
  vJson : TJSONObject;
begin
  vJson := TJSONObject.Create;
  vJson.AddPair('NormalizationRange', NormRangeToJSON);
  vJson.AddPair('InputLength', InputLength);
  vJson.AddPair('Root', NodeToJSON(FRoot));
  Result := vJson;
end;

procedure TDecisionTree.SaveToFile(const FileName: string);
var
  JSONTree: TJSONObject;
  JSONString: string;
  FileStream: TFileStream;
  Bytes: TBytes;
begin
  JSONTree := TreeToJSON;
  try
    JSONString := JSONTree.ToString;
    Bytes := TEncoding.UTF8.GetBytes(JSONString);

    FileStream := TFileStream.Create(FileName, fmCreate);
    try
      FileStream.Write(Bytes[0], Length(Bytes));
    finally
      FileStream.Free;
    end;
  finally
    JSONTree.Free;
  end;
end;

function JSONToNode(JSONNode: TJSONObject): TDecisionTreeNode;
var
  Node: TDecisionTreeNode;
  LeftChildJSON, RightChildJSON: TJSONObject;
begin
  Node := TDecisionTreeNode.Create;

  Node.FeatureIndex := JSONNode.GetValue<Integer>('FeatureIndex');
  Node.Threshold := JSONNode.GetValue<Double>('Threshold');
  if JSONNode.TryGetValue('LabelValue', Node.LabelValue) then
    Node.LabelValue := JSONNode.GetValue<string>('LabelValue');

  if JSONNode.TryGetValue('LeftChild', LeftChildJSON) then
    Node.LeftChild := JSONToNode(LeftChildJSON);

  if JSONNode.TryGetValue('RightChild', RightChildJSON) then
    Node.RightChild := JSONToNode(RightChildJSON);

  Result := Node;
end;

procedure TDecisionTree.LoadFromFile(const FileName: string);
var
  vJson: TJSONObject;
  JSONString: string;
  FileStream: TFileStream;
  Bytes: TBytes;
  Size: Integer;
begin
  FileStream := TFileStream.Create(FileName, fmOpenRead);
  try
    Size := FileStream.Size;
    SetLength(Bytes, Size);
    FileStream.Read(Bytes[0], Size);
    JSONString := TEncoding.UTF8.GetString(Bytes);

    vJson := TJSONObject.ParseJSONValue(JSONString) as TJSONObject;
    try
      FRoot := JSONToNode(vJson.FindValue('Root') as TJSONObject);
      InputLength := StrToInt(vJson.FindValue('InputLength').Value);
      JSONToNormRange(vJson.FindValue('NormalizationRange') as TJSONObject);
      Trained := True;
    finally
      vJson.Free;
    end;
  finally
    FileStream.Free;
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

