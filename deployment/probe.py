#!/usr/bin/env python3
"""Exercise login and stored configuration without logging credentials/cookies."""
import argparse
import http.cookiejar
import json
import pathlib
import urllib.error
import urllib.request


def env_values(path):
    result = {}
    for line in path.read_text().splitlines():
        if line and not line.startswith('#') and '=' in line:
            key, value = line.split('=', 1)
            result[key] = value
    return result


def session(base, env_path):
    credentials = env_values(env_path)
    jar = http.cookiejar.CookieJar()
    client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    client.addheaders = [('User-Agent', 'Mozilla/5.0 MoonTVDeploymentCheck/1.0'),
        ('Origin', base), ('Referer', base + '/login')]
    data = json.dumps({'username': credentials['USERNAME'], 'password': credentials['PASSWORD']}).encode()
    request = urllib.request.Request(base + '/api/login', data=data, headers={'Content-Type': 'application/json'})
    with client.open(request, timeout=20) as response:
        assert response.status == 200 and json.load(response).get('ok'), 'login failed'
    return client


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--base', default='http://127.0.0.1:3000')
    parser.add_argument('--seed', type=pathlib.Path)
    parser.add_argument('--env', type=pathlib.Path,
        default=pathlib.Path(__file__).resolve().parent / '.env')
    args = parser.parse_args()
    client = session(args.base, args.env)
    if args.seed:
        config = json.loads(args.seed.read_text(encoding='utf-8-sig'))
        request = urllib.request.Request(args.base + '/api/admin/config_file',
            data=json.dumps({'configFile': json.dumps(config, ensure_ascii=False)}).encode(),
            headers={'Content-Type': 'application/json'})
        with client.open(request, timeout=25) as response:
            assert json.load(response).get('success'), 'configuration import failed'
    with client.open(args.base + '/api/admin/config', timeout=20) as response:
        config = json.load(response)
    assert config['Role'] == 'owner', 'owner role missing'
    sources = config['Config']['SourceConfig']
    assert sources, 'no configured sources'
    with client.open(args.base + '/api/search/resources', timeout=20) as response:
        available = json.load(response)
    assert available, 'no available sources'
    try:
        request = urllib.request.Request(args.base + '/api/admin/config',
            headers={'User-Agent': 'Mozilla/5.0 MoonTVDeploymentCheck/1.0'})
        urllib.request.urlopen(request, timeout=15)
    except urllib.error.HTTPError as error:
        assert error.code == 401, 'unexpected anonymous response'
    else:
        raise AssertionError('anonymous administrator access allowed')
    print(json.dumps({'login': 'ok', 'owner': 'ok', 'anonymous_admin': 'blocked',
        'configured_sources': len(sources), 'available_sources': len(available)}, ensure_ascii=False))


if __name__ == '__main__':
    main()
