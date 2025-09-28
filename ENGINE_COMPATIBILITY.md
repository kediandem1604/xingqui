# Engine Compatibility Guide

## ⚠️ **Important Notice**

**Pikafish is a Chess engine, NOT a Xiangqi engine.**

## Engine Comparison

| Engine | Game Type | Status | Recommendation |
|--------|-----------|--------|----------------|
| **EleEye** | Xiangqi (Chinese Chess) | ✅ **Recommended** | Use for Xiangqi analysis |
| **Pikafish** | Chess (Western Chess) | ❌ **Not Compatible** | Do not use for Xiangqi |

## Why Pikafish Doesn't Work

1. **Different Game Rules**: Chess and Xiangqi have completely different rules
2. **Different Board**: Chess uses 8x8 board, Xiangqi uses 9x10 board  
3. **Different Pieces**: Chess pieces vs Xiangqi pieces (different movement patterns)
4. **Different FEN Format**: Chess FEN vs Xiangqi FEN are incompatible

## Recommended Solution

**Always use EleEye engine for Xiangqi analysis.**

EleEye is specifically designed for Xiangqi and will provide accurate analysis.

## Error Messages

If you see these errors, it's because Pikafish cannot understand Xiangqi:
- "Pikafish is a Chess engine, not Xiangqi"
- "Engine timeout" 
- "Position timeout"

**Solution**: Switch to EleEye engine in the dropdown menu.
