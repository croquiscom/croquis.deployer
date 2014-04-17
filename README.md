크로키 서비스 서버를 위한 배포 스크립트

# 적용

1. deploy.yaml을 작성한다.
1. devDependencies에 "croquis.deployer": "git+https://github.com/croquiscom/croquis.deployer.git" 추가
1. Cakefile에 require 'croquis.deployer/cakefile' 추가

# 사용법

* cake deploy - 서버에 배포
* cake run - 개발 모드로 서버 실행
* cake start - 실 서버에서 데몬으로 서비스 실행
* cake stop - 데몬 중지

# 로직

cake deploy를 실행하면

bin/deploy (클라이언트)
1. 현 디렉토리를 서버의 work/<project> 디렉토리에 복사한다.
1. 서버에서 bin/\_deploy\_on\_server.sh를 실행한다.

bin/\_deploy\_on\_server.sh (서버)
1. 필요한 모듈을 설치한다.
1. running/.versions 밑에 신선한 복사본을 만든다. (문제가 생겼을 떄 되돌아가기 쉽게 하기 위해서)
1. running/<project>에 최신 복사본에 대한 링크를 건다.
1. bin/start를 실행한다.

bin/start
1. forever로 lib/server.coffee를 데몬으로 띄운다.
