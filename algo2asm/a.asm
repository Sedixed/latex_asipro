\begin{algo}{puissance}{a,b}
  \IF{a = 0}
    \RETURN{b}
  \FI
  \SET{b}{b + 1}
  \RETURN{\CALL{puissance}{a - 1, b}}
\end{algo}
