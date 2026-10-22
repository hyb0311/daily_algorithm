// Day 001 - 两数之和 (Two Sum)
// 思路：哈希表记录「值 -> 下标」，一次遍历 O(n)。
// 编译：g++ -std=c++17 -O2 -Wall day001_two_sum.cpp -o day001
#include <cassert>
#include <iostream>
#include <unordered_map>
#include <vector>

std::vector<int> twoSum(const std::vector<int>& nums, int target) {
    std::unordered_map<int, int> seen;
    for (int i = 0; i < static_cast<int>(nums.size()); ++i) {
        auto it = seen.find(target - nums[i]);
        if (it != seen.end()) return {it->second, i};
        seen[nums[i]] = i;
    }
    return {};
}

int main() {
    assert((twoSum({2, 7, 11, 15}, 9) == std::vector<int>{0, 1}));
    assert((twoSum({3, 2, 4}, 6) == std::vector<int>{1, 2}));
    assert((twoSum({3, 3}, 6) == std::vector<int>{0, 1}));
    std::cout << "day001 全部测试通过\n";
    return 0;
}
