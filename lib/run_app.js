// 현재 디렉토리를 project_root로 변경하고 앱을 실행한다
const path = require('path');
const wd = process.argv[2];
const exec = path.resolve(process.argv[3]);
process.chdir(wd);
try {
  require('coffee-script/register');
} catch (error) {}
try {
  require('ts-node/register');
} catch (error) {}
require(exec);
