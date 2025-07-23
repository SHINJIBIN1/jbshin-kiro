// 대시보드 초기화
document.addEventListener('DOMContentLoaded', function() {
    // 현재 시간 설정
    updateLastUpdated();
    
    // AWS SDK 통합 시도
    if (typeof initializeAwsDashboard === 'function') {
        // AWS SDK 통합 함수가 있으면 호출
        initializeAwsDashboard();
    } else {
        // AWS SDK 통합 함수가 없으면 모의 데이터 사용
        console.log('AWS SDK 통합을 찾을 수 없음, 모의 데이터 사용');
        
        // 차트 초기화
        initializeCostChart();
        initializeMonitoringCharts();
        
        // 모의 데이터로 대시보드 업데이트
        updateDashboardWithMockData();
    }
});

// 마지막 업데이트 시간 설정
function updateLastUpdated() {
    const now = new Date();
    const formattedDate = now.toLocaleString('ko-KR', { 
        year: 'numeric', 
        month: '2-digit', 
        day: '2-digit',
        hour: '2-digit', 
        minute: '2-digit',
        second: '2-digit'
    });
    document.getElementById('last-updated').textContent = formattedDate;
}

// 비용 차트 초기화
function initializeCostChart() {
    const ctx = document.getElementById('cost-chart').getContext('2d');
    
    // 모의 데이터
    const labels = Array.from({length: 30}, (_, i) => `${i+1}일`);
    const data = Array.from({length: 30}, () => Math.random() * 10 + 5);
    
    new Chart(ctx, {
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

// 모니터링 차트 초기화
function initializeMonitoringCharts() {
    // CPU 사용률 차트
    const cpuCtx = document.getElementById('cpu-chart').getContext('2d');
    
    // 모의 데이터
    const timeLabels = Array.from({length: 24}, (_, i) => `${i}시`);
    const cpuData = Array.from({length: 24}, () => Math.random() * 80 + 10);
    
    new Chart(cpuCtx, {
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
    
    // 메모리 사용률 차트
    const memoryCtx = document.getElementById('memory-chart').getContext('2d');
    
    // 모의 데이터
    const memoryData = Array.from({length: 24}, () => Math.random() * 70 + 20);
    
    new Chart(memoryCtx, {
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

// 모의 데이터로 대시보드 업데이트 (AWS SDK 통합 전 임시 구현)
function updateDashboardWithMockData() {
    // 배포 규모 설정
    const scales = ['소규모', '중규모', '대규모'];
    const randomScale = scales[Math.floor(Math.random() * scales.length)];
    document.getElementById('current-scale').textContent = randomScale;
    
    // 비용 데이터 업데이트
    document.getElementById('monthly-cost').textContent = '$' + (Math.random() * 500 + 100).toFixed(2);
    document.getElementById('daily-cost').textContent = '$' + (Math.random() * 20 + 5).toFixed(2);
    document.getElementById('cost-change').textContent = (Math.random() * 20 - 10).toFixed(1) + '%';
    
    // 리소스 상태 업데이트
    updateResourceCard('ec2-status', Math.floor(Math.random() * 5) + 1);
    updateResourceCard('rds-status', Math.floor(Math.random() * 2) + 1);
    updateResourceCard('elb-status', Math.floor(Math.random() * 2));
    updateResourceCard('cache-status', Math.floor(Math.random() * 2));
    
    // 다이어그램 로딩 메시지 숨기기 (실제 다이어그램은 AWS SDK 통합 후 구현)
    document.querySelector('#infrastructure-diagram .loading-message').style.display = 'none';
}

// 리소스 카드 업데이트
function updateResourceCard(cardId, count) {
    const card = document.getElementById(cardId);
    const countElement = card.querySelector('.resource-count');
    const statusElement = card.querySelector('.resource-status');
    
    countElement.textContent = count;
    
    // 상태 설정 (실제 구현에서는 AWS SDK 데이터 기반)
    const statuses = ['정상', '주의 필요', '오류'];
    const statusClasses = ['status-healthy', 'status-warning', 'status-error'];
    
    const randomStatusIndex = Math.floor(Math.random() * statuses.length);
    statusElement.textContent = statuses[randomStatusIndex];
    statusElement.className = 'resource-status ' + statusClasses[randomStatusIndex];
}

// 다이어그램 통합 함수
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