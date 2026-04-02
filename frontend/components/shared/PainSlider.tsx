"use client"

import { PAIN_DESCRIPTIONS } from "@/lib/constants/options"

interface PainSliderProps {
  label: string
  value: number
  onChange: (v: number) => void
  showDescription?: boolean
  color?: "blue" | "orange" | "red"
}

const colorMap = {
  blue: "accent-blue-500",
  orange: "accent-orange-500",
  red: "accent-red-500",
}

export function PainSlider({
  label,
  value,
  onChange,
  showDescription = false,
  color = "blue",
}: PainSliderProps) {
  return (
    <div>
      <div className="flex justify-between items-baseline mb-1">
        <label className="text-sm font-medium">{label}</label>
        <span className="text-sm font-bold tabular-nums">{value}/10</span>
      </div>
      {showDescription && (
        <p className="text-xs text-gray-500 mb-2">{PAIN_DESCRIPTIONS[value]}</p>
      )}
      <input
        type="range"
        min={0}
        max={10}
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        className={`w-full h-2 rounded-lg appearance-none cursor-pointer bg-gray-200 ${colorMap[color]}`}
      />
      <div className="flex justify-between text-xs text-gray-400 mt-1">
        <span>0</span>
        <span>5</span>
        <span>10</span>
      </div>
    </div>
  )
}
