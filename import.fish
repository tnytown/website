#!/usr/bin/env fish

mkdir -p .staging
pushd .staging

for f in ~/Downloads/Export-*.zip
    unzip -q $f
    set base (ls *.md | sed -E 's/.md$//')
    test -z "$base" && continue;
    mv $base.md $base'/index.md'
    sed -Ei '
    1d # delete title line
    s/.*\/([^\/]+\.(jpg|jpeg|png))\)$/![alt for \1](\1)/ # image ref rewrite
    ' $base'/index.md'
    set slug (echo $base |
    sed -E 's/[^A-Za-z0-9 ]//g; s/ /-/g; s/-[^-]+$//' |
    awk '{print tolower($0)}')
    mv $base $slug
    echo $slug; ls $slug
end

read -P 'press any key to continue '
popd

mv -f .staging/* content/blog/
