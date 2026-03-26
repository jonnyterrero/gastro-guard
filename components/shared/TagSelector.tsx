"use client"

interface TagSelectorProps {
  label: string
  options: string[]
  selected: string[]
  onChange: (selected: string[]) => void
  colorActive?: string
  columns?: 2 | 3 | 4
}

const defaultActive = "bg-blue-500 text-white border-blue-500"
const defaultInactive =
  "bg-white text-gray-700 border-gray-200 hover:border-blue-300"

export function TagSelector({
  label,
  options,
  selected,
  onChange,
  colorActive = defaultActive,
  columns = 3,
}: TagSelectorProps) {
  const toggle = (opt: string) => {
    if (selected.includes(opt)) {
      onChange(selected.filter((s) => s !== opt))
    } else {
      onChange([...selected, opt])
    }
  }

  const gridClass =
    columns === 2
      ? "grid-cols-2"
      : columns === 4
        ? "grid-cols-2 md:grid-cols-4"
        : "grid-cols-2 md:grid-cols-3"

  return (
    <div>
      <label className="text-sm font-medium mb-2 block">{label}</label>
      <div className={`grid ${gridClass} gap-2`}>
        {options.map((opt) => (
          <button
            key={opt}
            type="button"
            onClick={() => toggle(opt)}
            className={`p-2 text-xs rounded-lg border transition-all ${
              selected.includes(opt) ? colorActive : defaultInactive
            }`}
          >
            {opt}
          </button>
        ))}
      </div>
      {selected.length > 0 && (
        <p className="text-xs text-gray-500 mt-2">
          Selected: {selected.join(", ")}
        </p>
      )}
    </div>
  )
}
