// 현재 디렉토리를 project_root로 변경하고 앱을 실행한다
const path = require('path');
const wd = process.argv[2];
const exec = path.resolve(process.argv[3]);
process.chdir(wd);
require('coffee-script/register');
require('ts-node/register'); // 디렉토리 변경 후 register를 해야 제대로 컴파일을 한다
require(exec);
