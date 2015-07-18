'use strict';

var gulp   = require('gulp');
var del = require('del');
var coffeelint = require('gulp-coffeelint');
var mocha = require('gulp-mocha');
var coffee = require('gulp-coffee');

require('coffee-script/register');

var CI = process.env.CI === 'true';

var paths = {
  coffee: ['./lib/**/*.coffee'],
  watch: ['./gulpfile.js', './lib/**', './spec/**', '!spec/{temp,temp/**}'],
  tests: ['./spec/**/*.coffee', '!spec/{temp,temp/**}']
};

gulp.task('lint', function () {
  return gulp.src(paths.coffee)
    .pipe(coffeelint())
    .pipe(coffeelint.reporter());
});

gulp.task('mocha', function (cb) {
  gulp.src(paths.tests)
    .pipe(mocha({reporter: CI ? 'spec' : 'nyan', timeout: '5s'}))
});

gulp.task('watch', ['test'], function () {
  gulp.watch(paths.watch, ['test']);
});

gulp.task('test', ['lint', 'mocha']);

gulp.task('clean', function(cb) {
  del(['dist/**/*'], cb);
});

gulp.task('dist', ['clean'], function () {
  return gulp.src(paths.coffee, {base: './lib'})
    .pipe(coffee({bare: true})).on('error', console.log)
    .pipe(gulp.dest('./dist'));
});

gulp.task('default', ['test']);
