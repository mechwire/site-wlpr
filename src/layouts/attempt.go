package nsum

import "fmt"

type Attempt struct{
	set bool
}

func (_ *Attempt) twoSum(nums []int, target int) [2]int {
	solution := Solution{}
	return solution.twoSum(nums, target)
}
