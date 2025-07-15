# Kubernetes Multi-Node Cluster on macOS (Multipass + Terraform)

해당 프로젝트는 **macOS (M1/M2 포함)** 환경에서 기존 UTM 기반으로 설치하는 방법 대신 Multipass, Terraform을 이용하여 다음과 같은 **Kubernetes 멀티 노드 클러스터 환경**을 자동으로 구축하는데 그 목적을 둔다.

## 사전 설치 사항
- Terraform v1.11.3 이상 : [Terraform 설치 링크](https://developer.hashicorp.com/terraform/install)
- multipass v1.15.1+mac : [multipass 설치 링크](https://canonical.com/multipass)
- helmfile / helm-diff


## 구성 요소
| 구성 요소 | 수량 | 설명 |
|-----------|------|------|
| Control Plane (Master) | 3대 | 고가용성 멀티 마스터 |
| Worker Node | 6대 | 서비스 워크로드 처리 |
| Redis VM | 1대 | Kubernetes 외부 Redis (패스워드 설정 포함) |
| MySQL VM | 1대 | Kubernetes 외부 MySQL (DB/계정 자동 생성 포함) |
| Flannel | ✅ | Pod 간 통신을 위한 CNI 플러그인 |
| Terraform | ✅ | 인프라 정의 및 상태 관리 |
| Multipass | ✅ | 로컬 VM 기반 클러스터 실행 |


## 구조
```
.
├── init/
│   ├── k8s.yaml             # K8s용 cloud-init
│   ├── redis.yaml           # Redis VM용 cloud-init
│   └── mysql.yaml           # MySQL VM용 cloud-init
├── shell/
│   ├── cluster-init.sh      # kubeadm init 실행
│   ├── join-all.sh          # Master/Worker 자동 Join
│   ├── redis-install.sh     # Redis 패스워드 설정
│   └── mysql-install.sh     # MySQL 루트/유저/DB 설정
├── main.tf                  # Terraform 메인 구성
├── variables.tf             # Redis/MySQL 계정/포트 변수
└── README.md                # 사용 설명서
```

## 설치 방법
### 1. 초기화 및 배포
```bash
terraform init
terraform apply -auto-approve
```

### 2. 삭제
```bash
terraform destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate* kubeconfig
```


## 🔐 Redis/MySQL 접속 정보 (예시)


Terraform `variables.tf` 에 정의된 기본값 기준으로 세팅
### Redis
- Host: `redis` VM IP
- Port: `6379`
- Password: `redispass`

### MySQL
- Host: `mysql` VM IP
- Port: `3306`
- User: `devuser`
- Password: `devpass`
- Database: `devdb`

