#include <bits/stdc++.h>
using namespace std;

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);
    char a;
    int la, ld, n = 0;
        
    while(cin >> a)
    {
        n ++;
        if(a == 'A') la = n;
        if(a == 'D') ld = n;
    }
    if(((la == 1 && ld == 4) || (la == 4 && ld == 1)) || (((la == 2 && ld == 3) || (la == 3 && ld == 2))))
    cout << "No";
    else cout << "Yes";
    return 0;
}
