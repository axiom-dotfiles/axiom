pragma Singleton
import QtQuick

// Splits an ordered list of cards into two newspaper columns (the first k on
// the left, the rest on the right) so both end as close together as they
// can, from the cards' heights. Used by the settings page. No file access,
// processes or services.
QtObject {
  id: root

  // The height of heights[from..to) stacked with `gap` between them
  function _stack(heights, from, to, gap) {
    let sum = 0;
    for (let i = from; i < to; i++)
      sum += heights[i];
    return to > from ? sum + gap * (to - from - 1) : 0;
  }

  // How many cards go in the left column (0..n): the split whose taller
  // column is shortest, the larger one on a tie (the left column fuller)
  function split(heights, gap) {
    const n = heights.length;
    const total = heights.reduce((sum, height) => sum + height, 0);
    // Running sums, so each split costs O(1)
    let left = total;
    let best = n;
    let bestHeight = Infinity;
    for (let k = n; k >= 0; k--) {
      if (k < n)
        left -= heights[k];
      const right = total - left;
      const tallest = Math.max(k > 0 ? left + gap * (k - 1) : 0, k < n ? right + gap * (n - k - 1) : 0);
      if (tallest < bestHeight) {
        best = k;
        bestHeight = tallest;
      }
    }
    return best;
  }

  // Each card's y within its column, with the first `k` on the left
  function tops(heights, k, gap) {
    const result = [];
    let y = 0;
    for (let i = 0; i < heights.length; i++) {
      if (i === k)
        y = 0;
      result.push(y);
      y += heights[i] + gap;
    }
    return result;
  }

  // The taller column's height, with the first `k` on the left
  function height(heights, k, gap) {
    return Math.max(root._stack(heights, 0, k, gap), root._stack(heights, k, heights.length, gap));
  }
}
