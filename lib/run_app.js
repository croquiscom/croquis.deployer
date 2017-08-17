// 현재 디렉토리를 project_root로 변경하고 앱을 실행한다
require('coffee-script/register');
require('ts-node/register');
const path = require('path');
const wd = process.argv[2];
const exec = path.resolve(process.argv[3]);
process.chdir(wd);
require(exec);
