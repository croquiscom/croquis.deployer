child_process = require 'child_process'
fs = require 'fs'
path = require 'path'
yaml = require 'js-yaml'

project_root = process.env.PROJECT_ROOT
if /versions\/\d{4}-\d{2}-\d{2},\d{2}:\d{2},[a-z0-9]{7}$/.test project_root
  project_root = path.resolve project_root, '..', '..', 'current'

config = yaml.safeLoad(fs.readFileSync project_root + '/deploy.yaml', 'utf-8')
if not Array.isArray config.cron_jobs
  return
crontab = config.cron_jobs.map (job) ->
  "#{job.pattern} #{project_root}/run_job.sh #{job.job}"
crontab.push "@reboot #{project_root}/on_boot.sh"
crontab.push ''
crontab = crontab.join('\n')

fs.writeFileSync "#{project_root}/.crontab", crontab
try child_process.execSync "crontab -l | grep -v #{project_root} >> #{project_root}/.crontab"
try child_process.execSync "crontab #{project_root}/.crontab"
