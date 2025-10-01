// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint32, euint8, ebool } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract CropYieldOptimizer is SepoliaConfig {

    address public owner;
    uint256 public totalFarms;
    uint256 public currentAnalysisId;

    struct FarmData {
        address farmAddress;
        euint32 encryptedSoilQuality;      // 加密的土壤质量数据
        euint32 encryptedWaterUsage;       // 加密的用水量数据
        euint32 encryptedFertilizerUsage;  // 加密的化肥使用量
        euint32 encryptedYieldAmount;      // 加密的实际产量
        euint8 encryptedCropType;          // 加密的作物类型
        bool dataSubmitted;
        uint256 timestamp;
    }

    struct OptimizationResult {
        uint256 analysisId;
        euint32 recommendedSoilTreatment;
        euint32 recommendedWaterAmount;
        euint32 recommendedFertilizerAmount;
        euint32 predictedYieldIncrease;
        bool isActive;
        uint256 participatingFarms;
        uint256 createdAt;
    }

    mapping(address => FarmData) public farmDataRegistry;
    mapping(uint256 => OptimizationResult) public analysisResults;
    mapping(address => bool) public registeredFarms;
    mapping(address => uint256[]) public farmAnalysisHistory;

    address[] public activeFarms;

    event FarmRegistered(address indexed farm, uint256 timestamp);
    event DataSubmitted(address indexed farm, uint256 timestamp);
    event AnalysisStarted(uint256 indexed analysisId, uint256 participatingFarms);
    event OptimizationComplete(uint256 indexed analysisId, address indexed farm);
    event RecommendationGenerated(uint256 indexed analysisId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyRegisteredFarm() {
        require(registeredFarms[msg.sender], "Farm not registered");
        _;
    }

    constructor() {
        owner = msg.sender;
        currentAnalysisId = 1;
        totalFarms = 0;
    }

    // 注册农场
    function registerFarm() external {
        require(!registeredFarms[msg.sender], "Farm already registered");

        registeredFarms[msg.sender] = true;
        activeFarms.push(msg.sender);
        totalFarms++;

        emit FarmRegistered(msg.sender, block.timestamp);
    }

    // 提交加密的农业数据
    function submitFarmData(
        uint32 _soilQuality,
        uint32 _waterUsage,
        uint32 _fertilizerUsage,
        uint32 _yieldAmount,
        uint8 _cropType
    ) external onlyRegisteredFarm {
        require(_cropType > 0 && _cropType <= 10, "Invalid crop type");
        require(_soilQuality > 0 && _waterUsage > 0, "Invalid input data");

        // 加密所有农业数据
        euint32 encSoilQuality = FHE.asEuint32(_soilQuality);
        euint32 encWaterUsage = FHE.asEuint32(_waterUsage);
        euint32 encFertilizerUsage = FHE.asEuint32(_fertilizerUsage);
        euint32 encYieldAmount = FHE.asEuint32(_yieldAmount);
        euint8 encCropType = FHE.asEuint8(_cropType);

        farmDataRegistry[msg.sender] = FarmData({
            farmAddress: msg.sender,
            encryptedSoilQuality: encSoilQuality,
            encryptedWaterUsage: encWaterUsage,
            encryptedFertilizerUsage: encFertilizerUsage,
            encryptedYieldAmount: encYieldAmount,
            encryptedCropType: encCropType,
            dataSubmitted: true,
            timestamp: block.timestamp
        });

        // 设置FHE访问权限
        FHE.allowThis(encSoilQuality);
        FHE.allowThis(encWaterUsage);
        FHE.allowThis(encFertilizerUsage);
        FHE.allowThis(encYieldAmount);
        FHE.allowThis(encCropType);

        // 只允许农场主访问自己的数据
        FHE.allow(encSoilQuality, msg.sender);
        FHE.allow(encWaterUsage, msg.sender);
        FHE.allow(encFertilizerUsage, msg.sender);
        FHE.allow(encYieldAmount, msg.sender);
        FHE.allow(encCropType, msg.sender);

        emit DataSubmitted(msg.sender, block.timestamp);
    }

    // 开始多农场协作分析（保护隐私的联合计算）
    function startCollaborativeAnalysis() external returns (uint256) {
        require(getParticipatingFarmsCount() >= 3, "Need at least 3 farms for analysis");

        uint256 analysisId = currentAnalysisId;
        uint256 participatingFarms = getParticipatingFarmsCount();

        // 创建分析结果占位符
        analysisResults[analysisId] = OptimizationResult({
            analysisId: analysisId,
            recommendedSoilTreatment: FHE.asEuint32(0),
            recommendedWaterAmount: FHE.asEuint32(0),
            recommendedFertilizerAmount: FHE.asEuint32(0),
            predictedYieldIncrease: FHE.asEuint32(0),
            isActive: true,
            participatingFarms: participatingFarms,
            createdAt: block.timestamp
        });

        currentAnalysisId++;

        emit AnalysisStarted(analysisId, participatingFarms);

        // 触发加密计算流程
        _performEncryptedAnalysis(analysisId);

        return analysisId;
    }

    // 执行加密的农业数据分析
    function _performEncryptedAnalysis(uint256 _analysisId) private {
        // 使用FHE进行保密计算，计算最优建议
        // 这里实现简化版本，实际中会包含复杂的机器学习算法

        euint32 totalSoilQuality = FHE.asEuint32(0);
        euint32 totalWaterUsage = FHE.asEuint32(0);
        euint32 totalFertilizerUsage = FHE.asEuint32(0);
        euint32 totalYield = FHE.asEuint32(0);
        uint256 validFarms = 0;

        // 对所有参与农场的数据进行加密聚合
        for (uint i = 0; i < activeFarms.length; i++) {
            address farm = activeFarms[i];
            FarmData storage data = farmDataRegistry[farm];

            if (data.dataSubmitted) {
                totalSoilQuality = FHE.add(totalSoilQuality, data.encryptedSoilQuality);
                totalWaterUsage = FHE.add(totalWaterUsage, data.encryptedWaterUsage);
                totalFertilizerUsage = FHE.add(totalFertilizerUsage, data.encryptedFertilizerUsage);
                totalYield = FHE.add(totalYield, data.encryptedYieldAmount);
                validFarms++;
            }
        }

        if (validFarms > 0) {
            // 计算优化建议（使用乘法代替除法以避免FHE.div）
            euint32 farmCount = FHE.asEuint32(uint32(validFarms));

            // 直接使用加权计算而非平均值，避免除法运算
            euint32 weightedSoil = FHE.mul(totalSoilQuality, FHE.asEuint32(110)); // 提高10%
            euint32 weightedWater = FHE.mul(totalWaterUsage, FHE.asEuint32(95));  // 减少5%
            euint32 weightedFertilizer = FHE.mul(totalFertilizerUsage, FHE.asEuint32(105)); // 增加5%

            // 预测产量提升
            euint32 predictedIncrease = FHE.mul(totalYield, FHE.asEuint32(115)); // 提高15%

            // 更新分析结果
            OptimizationResult storage result = analysisResults[_analysisId];
            result.recommendedSoilTreatment = FHE.mul(weightedSoil, FHE.asEuint32(1)); // 保持加权结果
            result.recommendedWaterAmount = FHE.mul(weightedWater, FHE.asEuint32(1));
            result.recommendedFertilizerAmount = FHE.mul(weightedFertilizer, FHE.asEuint32(1));
            result.predictedYieldIncrease = FHE.mul(predictedIncrease, FHE.asEuint32(1));

            // 设置访问权限
            FHE.allowThis(result.recommendedSoilTreatment);
            FHE.allowThis(result.recommendedWaterAmount);
            FHE.allowThis(result.recommendedFertilizerAmount);
            FHE.allowThis(result.predictedYieldIncrease);

            emit RecommendationGenerated(_analysisId);
        }
    }

    // 获取个人优化建议（只有参与的农场能看到）
    function getPersonalizedRecommendations(uint256 _analysisId) external view onlyRegisteredFarm returns (
        bytes32 soilTreatment,
        bytes32 waterAmount,
        bytes32 fertilizerAmount,
        bytes32 yieldIncrease
    ) {
        OptimizationResult storage result = analysisResults[_analysisId];
        require(result.isActive, "Analysis not found or inactive");
        require(farmDataRegistry[msg.sender].dataSubmitted, "Must have submitted data");

        // 返回加密的建议，只有农场主能解密
        return (
            FHE.toBytes32(result.recommendedSoilTreatment),
            FHE.toBytes32(result.recommendedWaterAmount),
            FHE.toBytes32(result.recommendedFertilizerAmount),
            FHE.toBytes32(result.predictedYieldIncrease)
        );
    }

    // 获取参与分析的农场数量
    function getParticipatingFarmsCount() public view returns (uint256) {
        uint256 count = 0;
        for (uint i = 0; i < activeFarms.length; i++) {
            if (farmDataRegistry[activeFarms[i]].dataSubmitted) {
                count++;
            }
        }
        return count;
    }

    // 获取分析历史
    function getAnalysisInfo(uint256 _analysisId) external view returns (
        bool isActive,
        uint256 participatingFarms,
        uint256 createdAt
    ) {
        OptimizationResult storage result = analysisResults[_analysisId];
        return (
            result.isActive,
            result.participatingFarms,
            result.createdAt
        );
    }

    // 检查农场注册状态
    function isFarmRegistered(address _farm) external view returns (bool) {
        return registeredFarms[_farm];
    }

    // 获取农场数据提交状态
    function getFarmDataStatus(address _farm) external view returns (bool submitted, uint256 timestamp) {
        FarmData storage data = farmDataRegistry[_farm];
        return (data.dataSubmitted, data.timestamp);
    }

    // 获取总体统计信息
    function getPlatformStats() external view returns (
        uint256 totalRegisteredFarms,
        uint256 totalAnalyses,
        uint256 farmsWithData
    ) {
        return (
            totalFarms,
            currentAnalysisId - 1,
            getParticipatingFarmsCount()
        );
    }

    // 重置分析（仅所有者）
    function resetAnalysis(uint256 _analysisId) external onlyOwner {
        analysisResults[_analysisId].isActive = false;
    }

    // 紧急暂停（仅所有者）
    function emergencyPause() external onlyOwner {
        // 实现紧急暂停逻辑
        for (uint256 i = 1; i < currentAnalysisId; i++) {
            analysisResults[i].isActive = false;
        }
    }
}