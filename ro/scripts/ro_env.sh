#!/bin/bash
# 修正: 环境变量块移到 .bashrc 顶部(绕过非交互 return)
BRC=$HOME/.bashrc
# 先删掉尾部旧块
sed -i '/# >>> open-eda env >>>/,/# <<< open-eda env <<</d' "$BRC"
# 插到第一行
sed -i '1i\
# >>> open-eda env >>>\
export PATH="$HOME/.nix-profile/bin:$PATH"\
export PDK_ROOT="$HOME/.volare"\
export PDK=sky130A\
# <<< open-eda env <<<' "$BRC"
echo "--- 非交互登录 shell 验证 ---"
bash -lc 'echo "PDK_ROOT=$PDK_ROOT PDK=$PDK"; which xschem magic'
