# Moon影视 VPS 部署

站点域名：`https://dy.liyao03.dpdns.org`。服务器：`root@91.213.186.133`，目录 `/opt/moontv`。

应用使用官方 `ghcr.io/moontechlab/lunatv` 镜像，配置中固定当前通过验证的摘要。Redis 7.4 采用 AOF 持久化及每日 RDB 备份，数据库无公网端口。应用只监听本机 `127.0.0.1:3000`，由现有 nginx 容器代理。

## 自动更新

- VPS 的 `moontv-update.timer` 每六小时检查官方 `latest` 镜像；新版本先备份，再更新并验证登录、管理员权限、资源配置与匿名访问限制。失败自动恢复旧镜像；数据库备份可用于人工恢复数据结构。仅更新此应用，不更新其他容器。
- `moontv-backup.timer` 每日备份，保留最近 14 个备份。备份包含管理员凭据，只能存放在受保护目录。
- `moontv-certificate.timer` 每日检查本站 HTTPS 证书并重新加载 nginx。
- GitHub 默认分支 `vps` 的 `Sync official LunaTV source` 每六小时同步官方应用源码，保留本站 `deployment/` 和 `.github/`。官方工作流不会自动覆盖本站工作流。`UPSTREAM_COMMIT` 标记对应官方提交。
- 长期无上游变动时，源码同步任务每 28 天写入一次活动记录，避免 GitHub 因不活跃停用定时任务。VPS 镜像更新使用 systemd，独立于 GitHub Actions。

## 运维命令

```sh
cd /opt/moontv
docker compose ps
python3 probe.py
systemctl list-timers 'moontv-*'
systemctl start moontv-update.service
journalctl -u moontv-update.service -n 40 --no-pager
./backup.sh
```

管理员凭据在服务器 `/opt/moontv/.env`，权限为 `600`。不得提交真实凭据、Redis 数据或备份。仓库中的配置不包含真实密码。

## 旧站保留和恢复

旧 Vercel 代码保存在 `main` 和 `legacy-vercel-20261017` 分支；本地 `deployment/private/legacy-vercel-20261017.bundle` 另有 Git 备份。迁移不删除 Vercel 项目。旧站用 localstorage，收藏及播放记录在浏览器中；本站启用 Redis 后不会自动把浏览器数据转成服务端数据。保留同一域名不会删除原浏览器数据，但原记录需要另行导入后才会显示在新账号中。

旧仓库的 20 项播放源已从原 `config.json` 导入新站数据库。后续源配置由管理员后台管理，官方更新不会覆盖数据库。

手动恢复旧应用版本：从最近的备份读取当时 `.env` 中的 `MOONTV_IMAGE`，仅替换当前 `.env` 的该项，再运行 `docker compose up -d --no-deps --wait app`。不要覆盖新产生的用户记录。若新版改变了数据库格式，应先另行备份当前数据，再按对应备份恢复数据库。

## 域名切换

Cloudflare 的 `dy` 记录应设置为 A 记录、内容 `91.213.186.133`，并移除同名旧 CNAME；可以保留代理开启。HTTPS 源站证书签发后使用 Full (strict)。首次签发需使 `http://dy.liyao03.dpdns.org/.well-known/acme-challenge/` 能到达新服务器；全站 HTTPS 重定向可在签发后恢复。

切换前，服务器的 `/.well-known/moontv-origin` 返回 `moontv-vps-91.213.186.133`，用于确认请求已到达新站。域名切换及外网登录验收完成前，应保留旧部署。
