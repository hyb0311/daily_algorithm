"""Day 001 - 两数之和 (Two Sum)

题目：给定整数数组 nums 和整数 target，返回和为 target 的两个元素的下标。

思路：哈希表记录「值 -> 下标」，遍历时先查 target - x 是否见过。
      每个元素只访问一次，时间复杂度 O(n)，空间 O(n)。
"""

from typing import List


def two_sum(nums: List[int], target: int) -> List[int]:
    seen: dict[int, int] = {}
    for i, x in enumerate(nums):
        need = target - x
        if need in seen:
            return [seen[need], i]
        seen[x] = i
    raise ValueError("题目保证有解，正常走不到这里")


if __name__ == "__main__":
    assert two_sum([2, 7, 11, 15], 9) == [0, 1]
    assert two_sum([3, 2, 4], 6) == [1, 2]
    assert two_sum([3, 3], 6) == [0, 1]
    print("day001 全部测试通过")
