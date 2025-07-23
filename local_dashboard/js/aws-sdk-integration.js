// AWS SDK 통합 스크립트
// AWS SDK for JavaScript v3 사용

// AWS SDK 설정
const awsConfig = {
    region: 'us-west-2', // 기본 리전 설정
    credentials: {
        // 실제 배포 시에는 IAM 역할 또는 Cognito Identity Pool을 사용하는 것이 좋습니다.
        // 이 예제에서는 임시 자격 증명을 사용합니다.
        accessKeyId: '', // 실제 배포 시 설정
        secretAccessKey: '' // 실제 배포 시 설정
    }
};

// AWS SDK 클라이언트 초기화
let ec2Client, rdsClient, elbv2Client, cloudFrontClient, cloudWatchClient, costExplorerClient, elastiCacheClient;

// AWS SDK 초기화 함수
async function initializeAwsSdk() {
    try {
        // AWS SDK 모듈 동적 로드
        const { EC2Client } = await import('https://cdn.jsdelivr.net/npm/@aws-sdk/client-ec2/+esm');
        const { RDSClient } = await import('https://cdn.jsdelivr.net/npm/@aws-sdk/client-rds/+esm');
        const { ElasticLoadBalancingV2Client } = await import('https://cdn.jsdelivr.net/npm/@aws-sdk/client-elastic-load-balancing-v2/+esm');
        const { CloudFrontClient } = await import('https://cdn.jsdelivr.net/npm/@aws-sdk/client-cloudfront/+esm');
        const { CloudWatchClient } = await import('https://cdn.jsdelivr.net/npm/@aws-sdk/client-cloudwatch/+esm');
        const { CostExplorerClient } = await import('https://cdn.jsdelivr.net/npm/@aws-sdk/client-cost-explorer/+esm');
        const { ElastiCacheClient } = await import('https://cdn.jsdelivr.net/npm/@aws-sdk/client-elasticache/+esm');
        
        // 클라이언트 초기화
        ec2Client = new EC2Client(awsConfig);
        rdsClient = new RDSClient(awsConfig);
        elbv2Client = new ElasticLoadBalancingV2Client(awsConfig);
        cloudFrontClient = new CloudFrontClient(awsConfig);
        cloudWatchClient = new CloudWatchClient(awsConfig);
        costExplorerClient = new CostExplorerClient(awsConfig);
        elastiCacheClient = new ElastiCacheClient(awsConfig);
        
        console.log('AWS SDK 초기화 완료');
        return true;
    } catch (error) {
        console.error('AWS SDK 초기화 오류:', error);
        
        // 오류 발생 시 모의 데이터로 대체
        updateDashboardWithMockData();
        return false;
    }
}

// 배포 규모 가져오기
async function fetchDeploymentScale() {
    try {
        // 배포 규모를 결정하는 태그를 가진 리소스 검색
        const { DescribeInstancesCommand } = await import('https://cdn.jsdelivr.net/npm/@aws-sdk/client-ec2/+esm');
        
        const command = new DescribeInstancesCommand({
            Filters: [
                {
                    Name: 'tag:Environment',
                    Values: ['small', 'medium', 'large']
                },
                {
                    Name: 'instance-state-name',
                    Values: ['running']
                }
            ]
        });
        
        const response = await ec2Client.send(command);
        
        // 인스턴스에서 Environment 태그 값 추출
        let scale = 'small'; // 기본값
        
        if (response.Reservations && response.Reservations.length > 0) {
            for (const reservation of response.Reservations) {
                for (const instance of reservation.Instances) {
                    if (instance.Tags) {
                        const envTag = instance.Tags.find(tag => tag.Key === 'Environment');
                        if (envTag) {
                            scale = envTag.Value;
                            break;
                        }
                    }
                }
            }
        }
        
        // 배포 규모 표시 업데이트
        document.getElementById('current-scale').textContent = scale === 'small' ? '소규모' : 
                                                              scale === 'medium' ? '중규모' : '대규모';
        
        // 다이어그램 로드
        loadInfrastructureDiagram(scale);
        
        return scale;
    } catch (error) {
        console.error('배포 규모 가져오기 오류:', error);
        document.getElementById('current-scale').textContent = '알 수 없음';
        return 'small'; // 기본값
    }
}

// EC2 인스턴스 정보 가져오기
async function fetchEC2Instances() {
    try {
        const { DescribeInstancesCommand } = await import('https://cdn.jsdelivr.net/npm/@aws-sdk/client-ec2/+esm');
        
        const command = new DescribeInstancesCommand({
            Filters: [
                {
                    Name: 'instance-state-name',
                    Values: ['running', 'pending', 'stopping', 'stopped']
                }
            ]
        });
        
        const response = await ec2Client.send(command);
        
        // 인스턴스 수 및 상태 계산
        let runningCount = 0;
        let stoppedCount = 0;
        let otherCount = 0;
        
        if (response.Reservations) {
            for (const reservation of response.Reservations) {
                for (const instance of reservation.Instances) {
                    if (instance.State.Name === 'running') {
                        runningCount++;
                    } else if (instance.State.Name === 'stopped') {
                        stoppedCount++;
                    } else {
                        otherCount++;
                    }
                }
            }
        }
        
        const totalCount = runningCount + stoppedCount + otherCount;
        
        // EC2 카드 업데이트
        const ec2Card = document.getElementById('ec2-status');
        ec2Card.querySelector('.resource-count').textContent = totalCount;
        
        let statusText = `실행 중: ${runningCount}, 중지됨: ${stoppedCount}`;
        if (otherCount > 0) {
            statusText += `, 기타: ${otherCount}`;
        }
        
        const statusElement = ec2Card.querySelector('.resource-status');
        statusElement.textContent = statusText;
        
        // 상태에 따른 클래스 설정
        if (runningCount === 0) {
            statusElement.className = 'resource-status status-warning';
        } else {
            statusElement.className = 'resource-status status-healthy';
        }
        
        return totalCount;
    } catch (error) {
        console.error('EC2 인스턴스 정보 가져오기 오류:', error);
        updateResourceCardWithError('ec2-status', '데이터 로드 실패');
        return 0;
    }
}

// RDS 인스턴스 정보 가져오기
async function fetchRDSInstances() {
    try {
        const { DescribeDBInstancesCommand } = await import('https://cdn.jsdelivr.net/npm/@aws-sdk/client-rds/+esm');
        
        const command = new DescribeDBInstancesCommand({});
        const response = await rdsClient.send(command);
        
        // RDS 인스턴스 수 및 상태 계산
        let availableCount = 0;
        let otherCount = 0;
        
        if (response.DBInstances) {
            for (const instance of response.DBInstances) {
                if (instance.DBInstanceStatus === 'available') {
                    availableCount++;
                } else {
                    otherCount++;
                }
            }
        }
        
        const totalCount = availableCount + otherCount;
        
        // RDS 카드 업데이트
        const rdsCard = document.getElementById('rds-status');
        rdsCard.querySelector('.resource-count').textContent = totalCount;
        
        let statusText = `사용 가능: ${availableCount}`;
        if (otherCount > 0) {
            statusText += `, 기타: ${otherCount}`;
        }
        
        const statusElement = rdsCard.querySelector('.resource-status');
        statusElement.textContent = statusText;
        
        // 상태에 따른 클래스 설정
        if (availableCount === 0) {
            statusElement.className = 'resource-status status-warning';
        } else {
            statusElement.className = 'resource-status status-healthy';
        }
        
        return totalCount;
    } catch (error) {
        console.error('RDS 인스턴스 정보 가져오기 오류:', error);
        updateResourceCardWithError('rds-status', '데이터 로드 실패');
        return 0;
    }
}

// 로드 밸런서 정보 가져오기
async function fetchLoadBalancers() {
    try {
        const { DescribeLoadBalancersCommand } = await import('https://cdn.jsdelivr.net/npm/@aws-sdk/client-elastic-load-balancing-v2/+esm');
        
        const command = new DescribeLoadBalancersCommand({});
        const response = await elbv2Client.send(command);
        
        // 로드 밸런서 수 계산
        const totalCount = response.LoadBalancers ? response.LoadBalancers.length : 0;
        
        // 로드 밸런서 카드 업데이트
        const elbCard = document.getElementById('elb-status');
        elbCard.querySelector('.resource-count').textContent = totalCount;
        
        if (totalCount > 0) {
            const statusElement = elbCard.querySelector('.resource-status');
            statusElement.textContent = '활성';
            statusElement.className = 'resource-status status-healthy';
        } else {
            const statusElement = elbCard.querySelector('.resource-status');
            statusElement.textContent = '없음';
            statusElement.className = 'resource-status';
        }
        
        return totalCount;
    } catch (error) {
        console.error('로드 밸런서 정보 가져오기 오류:', error);
        updateResourceCardWithError('elb-status', '데이터 로드 실패');
        return 0;
    }
}

// ElastiCache 정보 가져오기
async function fetchElastiCache() {
    try {
        const { DescribeCacheClustersCommand } = await import('https://cdn.jsdelivr.net/npm/@aws-sdk/client-elasticache/+esm');
        
        const command = new DescribeCacheClustersCommand({});
        const response = await elastiCacheClient.send(command);
        
        // ElastiCache 클러스터 수 및 상태 계산
        let availableCount = 0;
        let otherCount = 0;
        
        if (response.CacheClusters) {
            for (const cluster of response.CacheClusters) {
                if (cluster.CacheClusterStatus === 'available') {
                    availableCount++;
                } else {
                    otherCount++;
                }
            }
        }
        
        const totalCount = availableCount + otherCount;
        
        // ElastiCache 카드 업데이트
        const cacheCard = document.getElementById('cache-status');
        cacheCard.querySelector('.resource-count').textContent = totalCount;
        
        let statusText = `사용 가능: ${availableCount}`;
        if (otherCount > 0) {
            statusText += `, 기타: ${otherCount}`;
        }
        
        const statusElement = cacheCard.querySelector('.resource-status');
        statusElement.textContent = statusText;
        
        // 상태에 따른 클래스 설정
        if (totalCount === 0) {
            statusElement.textContent = '없음';
            statusElement.className = 'resource-status';
        } else if (availableCount === 0) {
            statusElement.className = 'resource-status status-warning';
        } else {
            statusElement.className = 'resource-status status-healthy';
        }
        
        return totalCount;
    } catch (error) {
        console.error('ElastiCache 정보 가져오기 오류:', error);
        updateResourceCardWithError('cache-status', '데이터 로드 실패');
        return 0;
    }
}

// 비용 데이터 가져오기
async function fetchCostData() {
    try {
        const { GetCostAndUsageCommand } = await import('https://cdn.jsdelivr.net/npm/@aws-sdk/client-cost-explorer/+esm');
        
        // 현재 날짜 계산
        const today = new Date();
        const firstDayOfMonth = new Date(today.getFullYear(), today.getMonth(), 1);
        const lastDayOfMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0);
        
        // 지난 달 계산
        const lastMonth = new Date(today.getFullYear(), today.getMonth() - 1, 1);
        const lastMonthEnd = new Date(today.getFullYear(), today.getMonth(), 0);
        
        // 현재 월 비용 조회
        const currentMonthCommand = new GetCostAndUsageCommand({
            TimePeriod: {
                Start: firstDayOfMonth.toISOString().split('T')[0],
                End: today.toISOString().split('T')[0]
            },
            Granularity: 'DAILY',
            Metrics: ['UnblendedCost'],
            GroupBy: [
                {
                    Type: 'DIMENSION',
                    Key: 'SERVICE'
                }
            ]
        });
        
        // 지난 달 비용 조회
        const lastMonthCommand = new GetCostAndUsageCommand({
            TimePeriod: {
                Start: lastMonth.toISOString().split('T')[0],
                End: lastMonthEnd.toISOString().split('T')[0]
            },
            Granularity: 'MONTHLY',
            Metrics: ['UnblendedCost']
        });
        
        // 병렬로 요청 실행
        const [currentMonthResponse, lastMonthResponse] = await Promise.all([
            costExplorerClient.send(currentMonthCommand),
            costExplorerClient.send(lastMonthCommand)
        ]);
        
        // 현재 월 일일 비용 데이터 추출
        const dailyCosts = currentMonthResponse.ResultsByTime.map(result => {
            return {
                date: result.TimePeriod.Start,
                cost: parseFloat(result.Total.UnblendedCost.Amount)
            };
        });
        
        // 현재 월 총 비용 계산
        const currentMonthTotal = dailyCosts.reduce((sum, day) => sum + day.cost, 0);
        
        // 일일 평균 비용 계산
        const dailyAverage = currentMonthTotal / dailyCosts.length;
        
        // 지난 달 총 비용
        const lastMonthTotal = lastMonthResponse.ResultsByTime.length > 0 ? 
            parseFloat(lastMonthResponse.ResultsByTime[0].Total.UnblendedCost.Amount) : 0;
        
        // 전월 대비 변화율 계산
        let changePercentage = 0;
        if (lastMonthTotal > 0) {
            // 현재 월의 예상 총 비용 계산 (일일 평균 * 월의 일 수)
            const daysInMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
            const projectedMonthTotal = dailyAverage * daysInMonth;
            
            changePercentage = ((projectedMonthTotal - lastMonthTotal) / lastMonthTotal) * 100;
        }
        
        // 비용 차트 업데이트
        updateCostChart(dailyCosts);
        
        // 비용 요약 업데이트
        document.getElementById('monthly-cost').textContent = '$' + currentMonthTotal.toFixed(2);
        document.getElementById('daily-cost').textContent = '$' + dailyAverage.toFixed(2);
        document.getElementById('cost-change').textContent = changePercentage.toFixed(1) + '%';
        
        // 변화율에 따른 색상 설정
        const costChangeElement = document.getElementById('cost-change');
        if (changePercentage > 10) {
            costChangeElement.style.color = 'var(--danger-color)';
        } else if (changePercentage < -10) {
            costChangeElement.style.color = 'var(--success-color)';
        } else {
            costChangeElement.style.color = 'var(--primary-color)';
        }
        
        return {
            currentMonthTotal,
            dailyAverage,
            changePercentage
        };
    } catch (error) {
        console.error('비용 데이터 가져오기 오류:', error);
        
        // 오류 발생 시 모의 데이터로 대체
        const mockMonthlyCost = (Math.random() * 500 + 100).toFixed(2);
        const mockDailyCost = (Math.random() * 20 + 5).toFixed(2);
        const mockChange = (Math.random() * 20 - 10).toFixed(1);
        
        document.getElementById('monthly-cost').textContent = '$' + mockMonthlyCost;
        document.getElementById('daily-cost').textContent = '$' + mockDailyCost;
        document.getElementById('cost-change').textContent = mockChange + '%';
        
        return {
            currentMonthTotal: parseFloat(mockMonthlyCost),
            dailyAverage: parseFloat(mockDailyCost),
            changePercentage: parseFloat(mockChange)
        };
    }
}

// CloudWatch 지표 가져오기
async function fetchCloudWatchMetrics() {
    try {
        const { GetMetricDataCommand } = await import('https://cdn.jsdelivr.net/npm/@aws-sdk/client-cloudwatch/+esm');
        
        // 현재 시간 및 24시간 전 계산
        const now = new Date();
        const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        
        // EC2 CPU 사용률 지표 요청
        const command = new GetMetricDataCommand({
            StartTime: twentyFourHoursAgo,
            EndTime: now,
            MetricDataQueries: [
                {
                    Id: 'cpu',
                    MetricStat: {
                        Metric: {
                            Namespace: 'AWS/EC2',
                            MetricName: 'CPUUtilization',
                            Dimensions: []
                        },
                        Period: 3600, // 1시간 간격
                        Stat: 'Average'
                    },
                    ReturnData: true
                },
                {
                    Id: 'memory',
                    Expression: 'SELECT AVG(mem_used_percent) FROM CWAgent GROUP BY InstanceId', // CloudWatch Agent 메모리 지표
                    Period: 3600,
                    ReturnData: true
                }
            ]
        });
        
        const response = await cloudWatchClient.send(command);
        
        // CPU 데이터 추출
        const cpuData = response.MetricDataResults.find(result => result.Id === 'cpu');
        const cpuValues = cpuData ? cpuData.Values : [];
        const cpuTimestamps = cpuData ? cpuData.Timestamps.map(ts => new Date(ts).getHours() + '시') : [];
        
        // 메모리 데이터 추출
        const memoryData = response.MetricDataResults.find(result => result.Id === 'memory');
        const memoryValues = memoryData ? memoryData.Values : [];
        
        // 모니터링 차트 업데이트
        updateMonitoringCharts(cpuTimestamps, cpuValues, memoryValues);
        
        return {
            cpuData: cpuValues,
            memoryData: memoryValues
        };
    } catch (error) {
        console.error('CloudWatch 지표 가져오기 오류:', error);
        
        // 오류 발생 시 모의 데이터로 대체
        const timeLabels = Array.from({length: 24}, (_, i) => `${i}시`);
        const cpuData = Array.from({length: 24}, () => Math.random() * 80 + 10);
        const memoryData = Array.from({length: 24}, () => Math.random() * 70 + 20);
        
        updateMonitoringCharts(timeLabels, cpuData, memoryData);
        
        return {
            cpuData,
            memoryData
        };
    }
}

// 비용 차트 업데이트
function updateCostChart(dailyCosts) {
    const ctx = document.getElementById('cost-chart').getContext('2d');
    
    // 기존 차트 제거
    if (window.costChart) {
        window.costChart.destroy();
    }
    
    // 데이터 준비
    const labels = dailyCosts.map(day => {
        const date = new Date(day.date);
        return `${date.getMonth() + 1}/${date.getDate()}`;
    });
    
    const data = dailyCosts.map(day => day.cost);
    
    // 새 차트 생성
    window.costChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: '일일 비용 ($)',
                data: data,
                backgroundColor: 'rgba(0, 115, 187, 0.2)',
                borderColor: 'rgba(0, 115, 187, 1)',
                borderWidth: 2,
                tension: 0.4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                y: {
                    beginAtZero: true,
                    title: {
                        display: true,
                        text: '비용 ($)'
                    }
                },
                x: {
                    title: {
                        display: true,
                        text: '날짜'
                    }
                }
            },
            plugins: {
                legend: {
                    position: 'top',
                },
                title: {
                    display: true,
                    text: '지난 30일 비용 추이'
                }
            }
        }
    });
    
    // 로딩 메시지 숨기기
    document.querySelector('#cost-analysis .loading-message').style.display = 'none';
}

// 모니터링 차트 업데이트
function updateMonitoringCharts(timeLabels, cpuData, memoryData) {
    // CPU 차트 업데이트
    const cpuCtx = document.getElementById('cpu-chart').getContext('2d');
    
    // 기존 차트 제거
    if (window.cpuChart) {
        window.cpuChart.destroy();
    }
    
    // 새 CPU 차트 생성
    window.cpuChart = new Chart(cpuCtx, {
        type: 'line',
        data: {
            labels: timeLabels,
            datasets: [{
                label: 'CPU 사용률 (%)',
                data: cpuData,
                backgroundColor: 'rgba(255, 153, 0, 0.2)',
                borderColor: 'rgba(255, 153, 0, 1)',
                borderWidth: 2,
                tension: 0.4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                y: {
                    beginAtZero: true,
                    max: 100,
                    title: {
                        display: true,
                        text: '사용률 (%)'
                    }
                },
                x: {
                    title: {
                        display: true,
                        text: '시간'
                    }
                }
            },
            plugins: {
                legend: {
                    position: 'top',
                },
                title: {
                    display: true,
                    text: '지난 24시간 CPU 사용률'
                }
            }
        }
    });
    
    // 메모리 차트 업데이트
    const memoryCtx = document.getElementById('memory-chart').getContext('2d');
    
    // 기존 차트 제거
    if (window.memoryChart) {
        window.memoryChart.destroy();
    }
    
    // 새 메모리 차트 생성
    window.memoryChart = new Chart(memoryCtx, {
        type: 'line',
        data: {
            labels: timeLabels,
            datasets: [{
                label: '메모리 사용률 (%)',
                data: memoryData,
                backgroundColor: 'rgba(40, 167, 69, 0.2)',
                borderColor: 'rgba(40, 167, 69, 1)',
                borderWidth: 2,
                tension: 0.4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                y: {
                    beginAtZero: true,
                    max: 100,
                    title: {
                        display: true,
                        text: '사용률 (%)'
                    }
                },
                x: {
                    title: {
                        display: true,
                        text: '시간'
                    }
                }
            },
            plugins: {
                legend: {
                    position: 'top',
                },
                title: {
                    display: true,
                    text: '지난 24시간 메모리 사용률'
                }
            }
        }
    });
    
    // 로딩 메시지 숨기기
    document.querySelectorAll('#monitoring .loading-message').forEach(el => {
        el.style.display = 'none';
    });
}

// 리소스 카드 오류 상태 업데이트
function updateResourceCardWithError(cardId, errorMessage) {
    const card = document.getElementById(cardId);
    const statusElement = card.querySelector('.resource-status');
    statusElement.textContent = errorMessage;
    statusElement.className = 'resource-status status-error';
}

// 다이어그램 로드 함수
function loadInfrastructureDiagram(scale) {
    // 배포 규모에 따른 다이어그램 로드
    const diagramImage = document.getElementById('diagram-image');
    const loadingMessage = document.querySelector('#infrastructure-diagram .loading-message');
    
    // 배포 규모가 제공되지 않은 경우 현재 표시된 규모 사용
    if (!scale) {
        const currentScale = document.getElementById('current-scale').textContent;
        scale = currentScale === '소규모' ? 'small' : 
                currentScale === '중규모' ? 'medium' : 'large';
    }
    
    // 다이어그램 이미지 경로 설정
    const diagramPath = `images/${scale}_infrastructure.png`;
    
    // 이미지 로드 시도
    diagramImage.src = diagramPath;
    diagramImage.alt = `${scale} 규모 인프라 다이어그램`;
    
    // 이미지 로드 이벤트 처리
    diagramImage.onload = function() {
        // 이미지 로드 성공 시 로딩 메시지 숨기기
        loadingMessage.style.display = 'none';
        diagramImage.style.display = 'block';
    };
    
    diagramImage.onerror = function() {
        // 이미지 로드 실패 시 Mermaid 다이어그램 표시 (향후 구현)
        console.error(`다이어그램 이미지 로드 실패: ${diagramPath}`);
        loadingMessage.textContent = '다이어그램을 불러올 수 없습니다.';
        diagramImage.style.display = 'none';
    };
}

// AWS 데이터로 대시보드 업데이트
async function updateDashboardWithAwsData() {
    try {
        // AWS SDK 초기화
        const sdkInitialized = await initializeAwsSdk();
        
        if (!sdkInitialized) {
            console.warn('AWS SDK 초기화 실패, 모의 데이터 사용');
            return;
        }
        
        // 병렬로 데이터 가져오기
        await Promise.all([
            fetchDeploymentScale(),
            fetchEC2Instances(),
            fetchRDSInstances(),
            fetchLoadBalancers(),
            fetchElastiCache(),
            fetchCostData(),
            fetchCloudWatchMetrics()
        ]);
        
        console.log('AWS 데이터로 대시보드 업데이트 완료');
    } catch (error) {
        console.error('대시보드 업데이트 오류:', error);
        
        // 오류 발생 시 모의 데이터로 대체
        updateDashboardWithMockData();
    }
}

// 대시보드 초기화 함수 (기존 dashboard.js에서 호출)
function initializeAwsDashboard() {
    // AWS SDK 통합 시도
    updateDashboardWithAwsData().catch(error => {
        console.error('AWS 대시보드 초기화 오류:', error);
        
        // 오류 발생 시 모의 데이터로 대체
        updateDashboardWithMockData();
    });
}