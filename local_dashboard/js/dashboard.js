// 대시보드 초기화
document.addEventListener('DOMContentLoaded', function() {
    // Mermaid 초기화
    mermaid.initialize({
        startOnLoad: true,
        theme: 'default',
        securityLevel: 'loose',
        fontFamily: 'Segoe UI, Tahoma, Geneva, Verdana, sans-serif'
    });
    
    // 탭 기능 초기화
    initializeTabs();
    
    // 다이어그램 탭 기능 초기화
    initializeDiagramSelector();
    
    // 현재 시간 설정
    updateLastUpdated();
    
    // 배포 규모 업데이트 (중규모로 고정)
    updateDeploymentScale('medium');
    
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
        initializeServiceCostChart();
        
        // 모의 데이터로 대시보드 업데이트
        updateDashboardWithMockData();
    }
});

// 탭 기능 초기화
function initializeTabs() {
    const tabButtons = document.querySelectorAll('.tab-button');
    const tabContents = document.querySelectorAll('.tab-content');
    
    // 초기 상태 설정: 모든 탭 콘텐츠 숨기고 첫 번째 탭만 표시
    tabContents.forEach((content, index) => {
        if (index === 0) {
            content.style.display = 'block';
        } else {
            content.style.display = 'none';
        }
    });
    
    tabButtons.forEach(button => {
        button.addEventListener('click', () => {
            // 모든 탭 버튼에서 active 클래스 제거
            tabButtons.forEach(btn => btn.classList.remove('active'));
            
            // 모든 탭 콘텐츠 숨기기
            tabContents.forEach(content => {
                content.style.display = 'none';
                content.classList.remove('active');
            });
            
            // 클릭한 버튼에 active 클래스 추가
            button.classList.add('active');
            
            // 해당 탭 콘텐츠 표시
            const tabId = button.getAttribute('data-tab');
            const activeContent = document.getElementById(tabId);
            activeContent.style.display = 'block';
            activeContent.classList.add('active');
            
            // 차트 리사이즈 (차트가 탭 전환 시 크기 조정 문제가 있을 수 있음)
            window.dispatchEvent(new Event('resize'));
        });
    });
    
    // 첫 번째 탭 버튼을 활성화
    tabButtons[0].classList.add('active');
}

// 다이어그램 탭 기능 초기화
function initializeDiagramSelector() {
    const diagramTabButtons = document.querySelectorAll('.diagram-tab-button');
    if (!diagramTabButtons.length) return;
    
    diagramTabButtons.forEach(button => {
        button.addEventListener('click', () => {
            // 모든 버튼에서 active 클래스 제거
            diagramTabButtons.forEach(btn => btn.classList.remove('active'));
            
            // 모든 다이어그램 콘텐츠 숨기기
            document.querySelectorAll('.diagram-content').forEach(content => {
                content.classList.remove('active');
            });
            
            // 클릭한 버튼에 active 클래스 추가
            button.classList.add('active');
            
            // 해당 다이어그램 콘텐츠 표시
            const diagramType = button.getAttribute('data-diagram');
            const diagramContent = document.getElementById(`${diagramType}-diagram-content`);
            if (diagramContent) {
                diagramContent.classList.add('active');
            }
            
            // Mermaid 다이어그램 다시 렌더링
            mermaid.init(undefined, document.querySelectorAll('.diagram-content.active .mermaid'));
        });
    });
}

// 배포 규모 업데이트
function updateDeploymentScale(scale) {
    // 한글 배포 규모 설정
    let koreanScale = '소규모';
    if (scale === 'medium') koreanScale = '중규모';
    if (scale === 'large') koreanScale = '대규모';
    
    // 배포 규모 표시 업데이트
    const currentScaleElement = document.getElementById('current-scale');
    if (currentScaleElement) currentScaleElement.textContent = koreanScale;
    
    const summaryScaleElement = document.getElementById('summary-scale');
    if (summaryScaleElement) summaryScaleElement.textContent = koreanScale;
    
    // 리소스 상태 업데이트
    if (scale === 'small') {
        updateResourceCard('ec2-status', 1); // 소규모는 EC2 인스턴스 1개
        updateResourceCard('vpc-status', 1);
        updateResourceCard('route53-status', 1);
        updateResourceCard('s3-status', 1);
        updateResourceCard('sg-status', 1);
        updateResourceCard('iam-status', 1);
    } else if (scale === 'medium') {
        updateResourceCard('ec2-status', 4); // 중규모는 EC2 인스턴스 4개
        updateResourceCard('vpc-status', 1);
        updateResourceCard('route53-status', 1);
        updateResourceCard('s3-status', 1);
        updateResourceCard('sg-status', 2);
        updateResourceCard('iam-status', 2);
    } else if (scale === 'large') {
        updateResourceCard('ec2-status', 8); // 대규모는 EC2 인스턴스 8개
        updateResourceCard('vpc-status', 1);
        updateResourceCard('route53-status', 1);
        updateResourceCard('s3-status', 2);
        updateResourceCard('sg-status', 3);
        updateResourceCard('iam-status', 3);
    }
}

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
    const loadingMessage = document.querySelector('#cost .loading-message');
    if (loadingMessage) {
        loadingMessage.style.display = 'none';
    }
}

// 서비스별 비용 차트 초기화
function initializeServiceCostChart() {
    const ctx = document.getElementById('service-cost-chart');
    if (!ctx) return;
    
    const ctxContext = ctx.getContext('2d');
    
    // 모의 데이터
    const data = {
        labels: ['EC2', 'Route 53', 'S3', 'CloudWatch', '기타'],
        datasets: [{
            label: '서비스별 비용 ($)',
            data: [25, 5, 8, 12, 3],
            backgroundColor: [
                'rgba(0, 115, 187, 0.7)',
                'rgba(255, 153, 0, 0.7)',
                'rgba(40, 167, 69, 0.7)',
                'rgba(220, 53, 69, 0.7)',
                'rgba(108, 117, 125, 0.7)'
            ],
            borderColor: [
                'rgba(0, 115, 187, 1)',
                'rgba(255, 153, 0, 1)',
                'rgba(40, 167, 69, 1)',
                'rgba(220, 53, 69, 1)',
                'rgba(108, 117, 125, 1)'
            ],
            borderWidth: 1
        }]
    };
    
    new Chart(ctxContext, {
        type: 'pie',
        data: data,
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'right',
                },
                title: {
                    display: true,
                    text: '서비스별 비용 분포'
                }
            }
        }
    });
    
    // 로딩 메시지 숨기기
    const loadingMessages = document.querySelectorAll('#cost .loading-message');
    if (loadingMessages.length > 1) {
        loadingMessages[1].style.display = 'none';
    }
}

// 모니터링 차트 초기화
function initializeMonitoringCharts() {
    // CPU 사용률 차트
    const cpuCtx = document.getElementById('cpu-chart');
    if (!cpuCtx) return;
    
    const cpuCtxContext = cpuCtx.getContext('2d');
    
    // 모의 데이터
    const timeLabels = Array.from({length: 24}, (_, i) => `${i}시`);
    const cpuData = Array.from({length: 24}, () => Math.random() * 80 + 10);
    
    new Chart(cpuCtxContext, {
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
    const memoryCtx = document.getElementById('memory-chart');
    if (!memoryCtx) return;
    
    const memoryCtxContext = memoryCtx.getContext('2d');
    
    // 모의 데이터
    const memoryData = Array.from({length: 24}, () => Math.random() * 70 + 20);
    
    new Chart(memoryCtxContext, {
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
    
    // 네트워크 트래픽 차트
    const networkCtx = document.getElementById('network-chart');
    if (!networkCtx) return;
    
    const networkCtxContext = networkCtx.getContext('2d');
    
    // 모의 데이터
    const networkInData = Array.from({length: 24}, () => Math.random() * 500 + 100);
    const networkOutData = Array.from({length: 24}, () => Math.random() * 200 + 50);
    
    new Chart(networkCtxContext, {
        type: 'line',
        data: {
            labels: timeLabels,
            datasets: [
                {
                    label: '네트워크 인바운드 (KB/s)',
                    data: networkInData,
                    backgroundColor: 'rgba(0, 115, 187, 0.2)',
                    borderColor: 'rgba(0, 115, 187, 1)',
                    borderWidth: 2,
                    tension: 0.4
                },
                {
                    label: '네트워크 아웃바운드 (KB/s)',
                    data: networkOutData,
                    backgroundColor: 'rgba(220, 53, 69, 0.2)',
                    borderColor: 'rgba(220, 53, 69, 1)',
                    borderWidth: 2,
                    tension: 0.4
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                y: {
                    beginAtZero: true,
                    title: {
                        display: true,
                        text: '트래픽 (KB/s)'
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
                    text: '지난 24시간 네트워크 트래픽'
                }
            }
        }
    });
    
    // 로딩 메시지 숨기기
    const loadingMessages = document.querySelectorAll('#monitoring .loading-message');
    loadingMessages.forEach(el => {
        if (el) el.style.display = 'none';
    });
}

// 모의 데이터로 대시보드 업데이트 (AWS SDK 통합 전 임시 구현)
function updateDashboardWithMockData() {
    // 배포 규모 설정 (중규모로 고정)
    const scale = '중규모';
    const currentScaleElement = document.getElementById('current-scale');
    if (currentScaleElement) currentScaleElement.textContent = scale;
    
    const summaryScaleElement = document.getElementById('summary-scale');
    if (summaryScaleElement) summaryScaleElement.textContent = scale;
    
    // 비용 데이터 업데이트
    const monthlyCostElement = document.getElementById('monthly-cost');
    if (monthlyCostElement) monthlyCostElement.textContent = '$' + (Math.random() * 500 + 100).toFixed(2);
    
    const dailyCostElement = document.getElementById('daily-cost');
    if (dailyCostElement) dailyCostElement.textContent = '$' + (Math.random() * 20 + 5).toFixed(2);
    
    const costChangeElement = document.getElementById('cost-change');
    if (costChangeElement) costChangeElement.textContent = (Math.random() * 20 - 10).toFixed(1) + '%';
    
    // 리소스 상태 업데이트 (중규모 리소스로 설정)
    updateResourceCard('ec2-status', 4); // 중규모는 EC2 인스턴스 4개
    updateResourceCard('vpc-status', 1);
    updateResourceCard('route53-status', 1);
    updateResourceCard('s3-status', 1);
    updateResourceCard('sg-status', 2);
    updateResourceCard('iam-status', 2);
}

// 리소스 카드 업데이트
function updateResourceCard(cardId, count) {
    const card = document.getElementById(cardId);
    if (!card) return;
    
    const countElement = card.querySelector('.resource-count');
    if (countElement) {
        countElement.textContent = count;
    }
    
    const statusElement = card.querySelector('.resource-status');
    if (statusElement) {
        if (count > 0) {
            statusElement.textContent = '정상';
            statusElement.className = 'resource-status status-healthy';
        } else {
            statusElement.textContent = '미사용';
            statusElement.className = 'resource-status';
        }
    }
}

// Mermaid 다이어그램 업데이트 함수
function updateMermaidDiagram(code) {
    const diagramContainer = document.querySelector('.diagram-content.active');
    if (!diagramContainer) return;
    
    // 기존 다이어그램 제거
    diagramContainer.innerHTML = '';
    
    // 새 다이어그램 요소 생성
    const pre = document.createElement('pre');
    pre.className = 'mermaid';
    pre.textContent = code;
    
    // 다이어그램 컨테이너에 추가
    diagramContainer.appendChild(pre);
    
    // Mermaid 다시 렌더링
    mermaid.init(undefined, pre);
}