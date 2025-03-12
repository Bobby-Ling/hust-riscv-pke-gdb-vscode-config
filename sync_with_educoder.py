# %%
import base64
import os
from pathlib import Path
import re
import sys
import httpx
from urllib.parse import urlparse, parse_qs, urljoin
import email
import gitignore_parser
from tqdm import tqdm

# %%
def post_file_edu(
    file_path: str,
    request_str: str,
    game_id: int,
    homework_common_id: int
):
    print(f"file: {file_path}")

    lines = request_str.strip().split('\n')
    request_line = lines[0].strip()
    header_str = "\r\n".join(lines[1:])
    method, path_with_query, _ = request_line.split(' ', 2)

    headers = dict(email.message_from_string(header_str))

    if 'Content-Length' in headers:
        del(headers['Content-Length'])

    # 'https://data.educoder.net/api/myshixuns/XXXXXXXX/update_file.json?zzud=XXXXXXXX'
    full_url = urljoin(f"https://{headers['Host']}", path_with_query.split(' ')[0])
    parsed_url = urlparse(full_url)
    # {'zzud': ['XXXXXXXX']}
    params = parse_qs(parsed_url.query)

    file = open(file_path)
    file_content = file.read()

    url = parsed_url.geturl()
    params = params
    payload = {
        "path": file_path,
        "evaluate": 0,
        "content": file_content,
        "game_id": game_id,
        "tab_type":1,
        "exercise_id": None,
        "homework_common_id": str(homework_common_id)
    }
    # headers['Content-Length'] = f'{len(json.dumps(payload))}'

    response = httpx.post(url, headers=headers, params=params, json=payload)
    try:
        response_json = response.json()
        response_content = base64.b64decode(response_json['content']['content']).decode('utf-8')
        # print(f"响应内容: {response.json()}")
        consistent = response_content == file_content
        if not consistent:
            print(f"是否一致: {consistent}")
    except Exception as e:
        print(f"状态码: {response.status_code}")
        print(f"Error: {e} {response_json}")

def ls_files(
    current_directory: str = str(Path(__file__).parent),
    include_pattern: str = r'.+\.[hSc]$',
    exclude_pattern: str = r'^spike_interface.*'
):
    include_regex = re.compile(include_pattern)
    exclude_regex = re.compile(exclude_pattern)
    matched_files = []

    gitignore_rules = gitignore_parser.parse_gitignore('.gitignore')

    for root, dirs, files in os.walk(current_directory):
        dirs[:] = [d for d in dirs if gitignore_rules is None or not gitignore_rules(d)]

        for file in files:
            file_path = os.path.join(root, file)
            relative_file_path = os.path.relpath(file_path, current_directory)

            if gitignore_rules is not None and gitignore_rules(relative_file_path):
                continue

            if include_regex.match(relative_file_path) and not exclude_regex.match(relative_file_path):
                matched_files.append(relative_file_path)

    return matched_files
# %%
# 1. F12得到原始请求头
request_str = """
POST /api/myshixuns/XXXXXXXX/update_file.json?zzud=XXXXXXXX HTTP/1.1
Host: data.educoder.net
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:136.0) Gecko/20100101 Firefox/136.0
Accept: application/json
Accept-Language: zh-CN,en-US;q=0.7,en;q=0.3
Accept-Encoding: gzip, deflate, br, zstd
Referer: https://www.educoder.net/tasks/XXXXXXXX
Content-Type: application/json; charset=utf-8
Pc-Authorization: 0x0
X-EDU-Type: pc
X-EDU-Timestamp: 00000000
X-EDU-Signature: 0x0
Content-Length: 571
Origin: https://www.educoder.net
DNT: 1
Connection: keep-alive
Cookie: autologin_trustie=0x0; _educoder_session=0x0
Sec-Fetch-Dest: empty
Sec-Fetch-Mode: cors
Sec-Fetch-Site: same-site
Priority: u=0
Pragma: no-cache
Cache-Control: no-cache
"""

def post_file(file_path: str):
    post_file_edu(
        file_path=file_path,
        request_str=request_str,
        # 2. 从请求的payload json里找到game_id和homework_common_id
        game_id=00000000,
        homework_common_id=00000000
    )

# %%
def main():
    files = ls_files()
    # for file in tqdm(files):
    for file in files:
        post_file(file)
# %%
if __name__ == "__main__":
    # 3. 运行
    print(sys.argv)
    if len(sys.argv) == 2:
        post_file(sys.argv[-1])
    else:
        main()
# %%
