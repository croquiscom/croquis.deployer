크로키 서비스 서버를 위한 배포 스크립트

# 적용

1. deploy.yaml을 작성한다.
1. devDependencies에 "@croquiscom/croquis.deployer": "0.10.0" 추가
1. Cakefile에 require '@croquiscom/croquis.deployer/cakefile' 추가

# 사용법

* cake deploy - 서버에 배포
* cake run - 개발 모드로 서버 실행
* cake run:test - 테스트 모드로 서버 실행
* cake start - 실 서버에서 데몬으로 서비스 실행
* cake stop - 데몬 중지

# EC2 배포

## deploy.yaml 설정
* server: 배포할 서버 주소
* project: 프로젝트 명. 디렉토리 이름이 된다

## 과정
cake deploy를 실행하면

bin/deploy (클라이언트)
1. 현 디렉토리를 서버의 work/<project> 디렉토리에 복사한다.
1. 서버에서 bin/\_deploy\_on\_server.sh를 실행한다.

bin/\_deploy\_on\_server.sh (서버)
1. 필요한 모듈을 설치한다.
1. running/<project>/versions 밑에 신선한 복사본을 만든다. (문제가 생겼을 떄 되돌아가기 쉽게 하기 위해서)
1. running/<project>/current에 최신 복사본에 대한 링크를 건다.
1. bin/start를 실행한다.

bin/start
1. forever로 lib/server.js를 데몬으로 띄운다.

# Elastic Beanstalk 배포

## deploy.yaml 설정
* elasticbeanstalk.region: 배포 리전
* elasticbeanstalk.application\_name: 어플리케이션 이름
* elasticbeanstalk.environment\_name: 환경 이름

## AWS 설정
* awscli 설치: pip install awscli
* jq 설치: brew install jq
* IAM 설정
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "elasticbeanstalk:*",
                "elasticloadbalancing:*",
                "autoscaling:*",
                "s3:*",
                "cloudformation:*"
            ],
            "Resource": "*"
        }
    ]
}
```

# 시그널

server.js 프로세스에 시그널을 보내면 다음과 같은 처리를 한다.

* SIGHUP
    * 모든 Worker를 재시작한다.
* SIGUSR2
    * 로그파일을 다시 연다.

server.js 프로세스는 자식 Worker를 재시작할 때 기존 자식 프로세스에 SIGTERM을 보낸다.
