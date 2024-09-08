#!/bin/bash

URL="https://www.baidu.com/"

echo "检查 URL: $URL 是否可访问（最多等待 4 秒）..."

# 使用 curl 检查 URL 的头信息，设置 4 秒的最大时间限制
HTTP_STATUS=$(curl -s --head --max-time 4 $URL | head -n 1)

# 如果 curl 命令超时，将返回非零状态
if [ $? -ne 0 ]; then
    echo "检查 URL 失败，可能是请求超时或无法连接"
    echo "执行登录操作..."

    # 执行登录操作并输出诊断信息
    LOGIN_COMMAND="/data/login -name 181134567898734 -passwd 12345678"
    echo "执行命令: $LOGIN_COMMAND"
    $LOGIN_COMMAND

    if [ $? -eq 0 ]; then
        echo "登录成功"
    else
        echo "登录失败，请检查命令和凭证"
    fi
else
    echo "收到的 HTTP 响应: $HTTP_STATUS"
    
    # 检查是否包含 "200 OK"
    if echo "$HTTP_STATUS" | grep "200 OK" > /dev/null; then
        echo "URL 可访问，状态码为 200 OK"
    else
        echo "URL 不可访问，执行登录操作..."

        # 执行登录操作并输出诊断信息
        LOGIN_COMMAND="/data/login -name 19999999999 -passwd 12345678"
        echo "执行命令: $LOGIN_COMMAND"
        $LOGIN_COMMAND

        if [ $? -eq 0 ]; then
            echo "登录成功"
        else
            echo "登录失败，请检查命令和凭证"
        fi
    fi
fi
