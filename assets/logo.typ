#set page(width: 200pt, height: 200pt, fill: none)

#let logo(width: 200pt) = {
  // Gradient colors
  let color-top = rgb("#A8206E")
  let color-mid = rgb("#D72C4A")
  let color-bot = rgb("#FF6B35")

  let grad = gradient.linear(color-top, color-mid, color-bot, angle: 90deg)
  let gradShort = gradient.linear(color-top, color-bot, color-bot, color-bot, angle: 90deg)

  // Funnel
  box(width: width, height: width, {
    place(
      dx: 0pt,
      dy: 5pt,
      polygon(
        fill: none,
        stroke: (paint: grad, thickness: 14pt, cap: "round", join: "round"),
        (-15pt, 0pt),
        (165pt, 0pt),

        (95pt, 80pt),
        (91pt, 85pt),

        (91pt, 120pt),
        (59pt, 150pt),

        (59pt, 85pt),
        (55pt, 80pt),
      )
    )

    // Text
    place(
      dx: 33pt,
      dy: 18pt,
      text(35pt, weight: "bold", fill: gradShort, tracking: -2.5pt, font: "IBM Plex Sans")[FILTR]
    )
  })
}

#logo()
