# daily_algorithm

每日算法练习记录。一份题解、一个测试，持续积累。

## 目录结构

```
daily_algorithm/
├── python/         # Python 题解（主力）
│   └── day001_two_sum.py
├── cpp/            # C++ 题解（可选，不需要可删掉整个目录）
│   └── day001_two_sum.cpp
├── .gitignore
└── README.md
```

命名规则：`dayNNN_题目短名.py`，例如 `day042_lru_cache.py`。题号不足三位补零，保证文件排序就是时间顺序。

## 怎么跑

Python：

```powershell
python python/day001_two_sum.py
```

C++：

```powershell
g++ -std=c++17 -O2 -Wall cpp/day001_two_sum.cpp -o cpp/day001.exe
.\cpp\day001.exe
```

## 每日提交流程

```powershell
git add .
git commit -m "day002: 有效的括号"
git push
```

提交信息就写「dayNNN: 题目名」，回看历史一目了然。

## 刷题习惯建议

- 每道题**先写思路注释再写代码**，注释里写清复杂度，日后复习看注释就够。
- 每份题解自带 `assert` 测试（Python 的 `__main__` / C++ 的 `assert`），改错了能立刻发现。
- 卡住超过 40 分钟的题，先看提示再看题解，然后把「自己的错因」写进文件顶部注释。


## 新建题解（自动生成双语言模板）

```powershell
.\new.ps1 2 "有效的括号"                  # 生成 python/day002.py + cpp/day002.cpp
.\new.ps1 2 "有效的括号" -Slug valid_paren # 文件名带英文后缀
.\new.ps1 3 "合并区间" -NoCpp              # 只要 Python
```

标题会写进文件头，题目/思路/复杂度留空给你填。文件已存在时会直接拒绝，不会覆盖你写了一半的代码。