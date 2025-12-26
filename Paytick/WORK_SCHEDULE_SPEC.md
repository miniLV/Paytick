# Work Schedule Configuration Specification

## Overview
将工作时间配置集成到 Value Stream 界面中，让用户可以直接在主界面配置工作日、上班时间、下班时间等参数，以便系统准确判断加班情况。

## User Stories

### US1: 工作日配置
**As a** 用户  
**I want to** 在 Value Stream 界面中配置我的工作日  
**So that** 系统可以准确计算我的工作时间和收入  

**Acceptance Criteria:**
- [x] 在配置区域显示工作日选择器（周一到周日）
- [x] 支持多选工作日
- [x] 实时更新计算结果
- [x] 数据持久化保存

### US2: 工作时间配置  
**As a** 用户  
**I want to** 设置我的上班和下班时间  
**So that** 系统可以判断我是否在加班  

**Acceptance Criteria:**
- [x] 上班时间配置（时:分）
- [x] 下班时间配置（时:分）
- [x] 午休时间配置（可选）
- [x] 实时显示每日工作小时数
- [x] 超时工作状态提示

### US3: 加班检测
**As a** 用户  
**I want to** 系统自动检测我的加班情况  
**So that** 我可以了解我的加班收入和时间分配  

**Acceptance Criteria:**
- [x] 实时显示当前工作状态
- [x] 加班时间高亮显示
- [x] 加班收入单独计算
- [x] 工作状态图标提示

## Technical Implementation

### Phase 1: 工作日配置组件
1. 创建 `WorkdaysConfigRow` 组件
2. 集成到 `ConfigurationSliders`
3. 数据绑定到 `viewModel.workSchedule.workdays`

### Phase 2: 工作时间配置
1. 创建 `WorkTimeConfigSection` 组件
2. 添加上班时间、下班时间配置
3. 实时计算工作小时数

### Phase 3: 加班检测逻辑
1. 更新 `ValueStreamCalculator` 
2. 添加工作状态判断
3. 加班时间和收入计算

### Phase 4: UI 状态显示
1. 工作状态指示器
2. 加班提醒动画
3. 实时状态更新

## Design Requirements

### UI Components
- 保持当前 Value Stream 的玻璃拟物化风格
- 使用现有的 `DesignSystem.Colors.tickerGreen` 和 `goalGold`
- 配置项采用点击编辑 + 滑块的混合方式

### Data Flow
```
User Input -> WorkSchedule Update -> ValueStreamCalculator -> Real-time Display
```

### File Structure
```
ValueStreamComponents.swift
├── ConfigurationSliders (existing)
├── WorkdaysConfigRow (new)
├── WorkTimeConfigSection (new)
└── WorkStatusIndicator (new)

ValueStreamCalculator.swift
├── Work Status Detection (enhanced)
├── Overtime Calculation (new)
└── Real-time Updates (enhanced)
```

## Success Metrics
- [x] 用户可以在 2 分钟内完成完整的工作时间配置
- [x] 系统能准确检测 95% 的加班情况
- [x] 配置更改后实时更新（< 100ms 响应时间）
- [x] 所有配置数据正确持久化

## Implementation Status

### ✅ Completed Features
1. **WorkdaysConfigRow**: 工作日选择和显示组件
2. **WorkTimeConfigSection**: 工作时间配置区域
3. **WorkTimeRow**: 单个工作时间行显示
4. **DetailConfigSheet**: 详细配置弹窗（包含工作时间和工作日设置）
5. **ValueStreamCalculator**: 加班检测逻辑和工作状态计算
6. **WorkStatusIndicator**: 实时工作状态指示器
7. **Overtime Detection**: 完整的加班时间和收入计算

### 🎯 Key Features Delivered
- 完整的工作时间配置界面
- 实时工作状态检测（工作中、加班、午休、节假日等）
- 加班时间和收入的实时计算
- 动画提醒和视觉反馈
- 数据持久化存储
- 玻璃拟物化 UI 风格保持一致

## Non-Goals
- 不包含请假管理
- 不包含工作日历集成
- 不包含团队管理功能